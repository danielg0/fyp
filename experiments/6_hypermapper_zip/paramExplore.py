#!/usr/bin/env python3

import argparse
import hypermapper
import os
import pathlib
import re
import subprocess
import tempfile

# command arguments for all the paths we need
parser = argparse.ArgumentParser(
	prog = "BO SimPoint Experiment",
	description = "Optimise hardware parameters using SimPoint sets",
)
# csv data out
parser.add_argument(
	"--data-out",
	type = argparse.FileType("w"),
	required = True,
	help = "File to write out CSV statistics to",
)
# gem5 running
parser.add_argument(
	"--gem5-binary",
	type = pathlib.Path,
	required = True,
	help = "Gem5 binary used for simulation"
)
parser.add_argument(
	"--gem5-configfile",
	type = pathlib.Path,
	required = True,
	help = "Gem5 configuration file"
)
parser.add_argument(
	"gem5cmd",
	type = str,
	nargs = "+",
	help = "Gem5 options. Should include binary to simulate and its options, machine setup not being experimented on (CPU type, memory options), path redirections"
)
parser.add_argument(
	"--gem5-checkpoints",
	type = pathlib.Path,
	required = True
)
parser.add_argument(
	"--weightfile",
	nargs = "+",
	type = str,
	required = True,
	help = "A target interval and weight file for that interval of the form 'interval,./path/to/interval.weights'"
)

# other required binaries
parser.add_argument(
	"--time",
	type = pathlib.Path,
	help = "The location of the /usr/bin/time binary",
	default = pathlib.Path("/usr/bin/time"),
)
parser.add_argument(
	"--gem5tomcpat",
	type = pathlib.Path,
	help = "The location of the gem5tomcpat.py helper script",
	required = True,
)
parser.add_argument(
	"--gem5tomcpat-template-warm",
	type = pathlib.Path,
	help = "gem5tomcpat config file for checkpoints with warmup (ie. with switch_cpus[0] rather than cpu[0])",
	required = True,
)
parser.add_argument(
	"--gem5tomcpat-template-cold",
	type = pathlib.Path,
	help = "gem5tomcpat config file for checkpoints with no warmup (ie. that uses values from cpu[0])",
	required = True,
)

parser.add_argument(
	"--mcpat",
	type = pathlib.Path,
	help = "The path to the mcpat binary",
	required = True,
)

args = parser.parse_args()
print(args)

# parse target intervals and weights file
# greatest interval given used as baseline
# weights is a dict of interval -> {a dict of cpt_id -> its weight}
weights = {}
for inWeight in args.weightfile:
	try:
		interval_s, weightpath = inWeight.split(",")
		interval = int(interval_s)
		weights[interval] = {}
		weightfile = open(weightpath, "r")
		for simpoint in weightfile:
			weight_s, cpt_id = simpoint.split(" ")
			weight = float(weight_s)
			weights[interval][cpt_id] = weight
	except:
		print("Got error parsing while processing weight '" + inWeight + "'")
baseline = max(weights.keys())

# run gem5 once with given parameters and then pass through mcpat to get power/area
# params is a dict with the fields:
#   "cpt_id": checkpoint id to run
#           : if negative, no warmup, and absolute value is interval to simulate for
#   "cpt_dir": checkpoint directory to run
#
#   "rob_size": size of reorder buffer
#   "lsq_size": size of load/store queues
#   "p_width": pipeline width
# returned is None or a dict with the fields:
#   "energy": energy used in nanojoules/instruction
#   "performance": in cpi (cycles/instruction)
#   "time": total user cpu time spent processing
def run_gem5_mcpat(params):
	# increase this process' oom score
	oom_score = open("/proc/self/oom_score_adj", "w")
	oom_score.write("500")
	oom_score.close()

	# get tempdir to run gem5 in
	with tempfile.TemporaryDirectory(delete=False) as tmpdirname:
		# create folder to run gem5 in
		os.mkdir(tmpdirname + "/gem5")

		# timing data
		gem5_command = [
			str(args.time.absolute()),
			"--output", tmpdirname + "/gem5.timing"
		]

		# fixed gem5 config
		gem5_command.extend([
			str(args.gem5_binary.absolute()),
			"--outdir", tmpdirname + "/gem5/",
			str(args.gem5_configfile),
		])
		gem5_command.extend(list(tuple(args.gem5cmd)))

		# experiment variable prefix changes if no warmup
		prefix = "system.switch_cpus[:]." if (params["cpt_id"] >= 0) else "system.cpu[:]."

		# hypermapper experiment variables
		gem5_command.extend([
			"-P", prefix + "numROBEntries=" + str(params["rob_size"]),
			"-P", prefix + "LQEntries=" + str(params["lsq_size"]),
			"-P", prefix + "SQEntries=" + str(params["lsq_size"]),
		])
		pipeline_stages = ["fetch", "decode", "rename", "dispatch", "issue", "wb", "squash", "commit"]
		for stage in pipeline_stages:
			gem5_command.extend(["-P", prefix + stage + "Width=" + str(params["p_width"])])

		# gem5 checkpoint
		if (params["cpt_id"] >= 0):
			gem5_command.extend([
				"--restore-simpoint-checkpoint",
				# GEM5 SIMPOINT RESTORATION USES 1-INDEXING
				"-r", str(params["cpt_id"] + 1),
				"--checkpoint-dir", str(params["cpt_dir"])
			])
		else:
			gem5_command.extend(["--maxinsts", str(abs(params["cpt_id"]))])
	
		# execute gem5
		print(" ".join(gem5_command))
		with open(tmpdirname + "/gem5/log.log", "w") as log:
			with open(tmpdirname + "/gem5/err.log", "w") as err:
				process = subprocess.Popen(gem5_command, stdout=log, stderr=err)
				status = process.wait()

				if status != 0:
					return None

		# convert gem5 config/stats to mcpat input
		convert = [str(args.gem5tomcpat.absolute()),
			"--template", str(args.gem5tomcpat_template_warm if (params['cpt_id'] >= 0) else args.gem5tomcpat_template_cold),
			"--stats", tmpdirname + "/gem5/stats.txt",
			"--config", tmpdirname + "/gem5/config.json",
			"--output", tmpdirname + "/mcpat-in.xml",
		]
		print(" ".join(convert))
		with open(tmpdirname + "/gem5tomcpat.log", "w") as log:
			with open(tmpdirname + "/gem5tomcpat.err", "w") as err:
				process = subprocess.Popen(convert, stdout=log, stderr=err)
				status = process.wait()

				if status != 0:
					return None

		# run mcpat on converted input
		mcpat_command = [
			str(args.time.absolute()),
			"--output", tmpdirname + "/mcpat.timing",
			str(args.mcpat.absolute()),
			"-infile", tmpdirname + "/mcpat-in.xml",
			"-print_level", "1",
			"-opt_for_clk", "1"
		]
		print(" ".join(mcpat_command))
		with open(tmpdirname + "/mcpat.out", "w") as out:
			with open(tmpdirname + "/mcpat.err", "w") as err:
				process = subprocess.Popen(mcpat_command, stdout=out, stderr=err)
				status = process.wait()

				if status != 0:
					return None

		# pull out performance and instruction/cycle count from stats.txt
		# overwrite parsed value so we get the last match present
		cpi = None
		instructions = None
		simtime = None
		pattern_cpi = re.compile(r"^system.switch_cpus.cpi\s+(\d+\.\d+)")
		pattern_insn = re.compile(r"^system.switch_cpus.commitStats0.numInsts\s+(\d+)")
		pattern_simtime = re.compile(r"^simSeconds\s+(\d+\.\d+)")
		statfile = open(tmpdirname + "/gem5/stats.txt", "r")
		for statline in statfile:
			match_cpi = pattern_cpi.match(statline)
			if match_cpi is not None:
				cpi = float(match_cpi.group(1))
			match_insn = pattern_insn.match(statline)
			if match_insn is not None:
				instructions = int(match_insn.group(1))
			match_simtime = pattern_simtime.match(statline)
			if match_simtime is not None:
				simtime = float(match_simtime.group(1))
		statfile.close()
		# pull out power information from mcpat
		# use the first match found (overall processor power)
		mcpat_report = open(tmpdirname + "/mcpat.out", "r").read()
		subthreshold_leakage = float(
			re.search(r"Subthreshold Leakage = (\d+\.\d+) W", mcpat_report)
				.group(1)
		)
		gate_leakage = float(
			re.search(r"Gate Leakage = (\d+\.\d+) W", mcpat_report)
				.group(1)
		)
		runtime_dynamic = float(
			re.search(r"Runtime Dynamic = (\d+\.\d+) W", mcpat_report)
				.group(1)
		)

		# parse timing files to get total CPU user time spent processing this
		time_gem5 = float(re.search(r"(\d+\.\d+)user",
			open(tmpdirname + "/gem5.timing", "r").read()).group(1))
		time_mcpat = float(re.search(r"(\d+\.\d+)user",
			open(tmpdirname + "/mcpat.timing", "r").read()).group(1))

		# energy is in nanojoules, scale simtime
		energy = ((1000000000 * simtime) * (subthreshold_leakage + gate_leakage + runtime_dynamic)) / instructions
		return {"energy": energy, "performance": cpi, "time": (time_gem5 + time_mcpat)}

# compute multiple simpoint metrics in parallel with passed in parameters, whilst logging process to a .csv
# takes a dictionary:
#   "rob_size": (array) size of reorder buffer
#   "lsq_size": (array) size of load/store queues
#   "p_width": (array) pipeline width
#   "interval_width": (array) interval width to use
def run_parallel_gem5(base_params):
	print(base_params)
	exp_count = len(base_params["rob_size"])
	return {"energy": [0] * exp_count, "performance": [0] * exp_count}

hypermapper.optimizer.optimize("scenario.json", run_parallel_gem5)
