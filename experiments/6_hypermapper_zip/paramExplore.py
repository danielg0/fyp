#!/usr/bin/env python3

THREADS=10

curr = open("./curr", "w")
curr.write("0")
curr.close()

import argparse
import hypermapper
import os
import pathlib
import re
import subprocess
import tempfile
import time
import multiprocessing

# command arguments for all the paths we need
parser = argparse.ArgumentParser(
	prog = "BO SimPoint Experiment",
	description = "Optimise hardware parameters using SimPoint sets",
)
# csv data out & text log (to supplement hypermapper)
parser.add_argument(
	"--data-out",
	type = argparse.FileType("w"),
	required = True,
	help = "File to write out CSV statistics to",
)
parser.add_argument(
	"--log",
	type = argparse.FileType("w"),
	required = True,
	help = "Supplemental logfile",
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
	required = True,
	help = "A folder containing folders for each interval, that then contain checkpoints"
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
args.log.write(str(args) + "\n")

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
			weight_s, cpt_id_s = simpoint.split(" ")
			weight = float(weight_s)
			cpt_id = int(cpt_id_s)
			weights[interval][cpt_id] = weight
	except:
		args.log.write("Got error parsing while processing weight '" + inWeight + "'\n")
baseline = max(weights.keys())

# run gem5 once with given parameters and then pass through mcpat to get power/area
# params is a dict with the fields:
#   "cpt_id": checkpoint id to run
#           : if negative, no warmup, and absolute value is interval to simulate for
#		^ note this is currently never the case
#   "cpt_dir": checkpoint directory to run
#
#   "rob_size": size of reorder buffer
#   "lq_size": size of load queue
#   "sq_size": size of store queue
#   "p_width": pipeline width
#   "int_regs", "float_regs", "vec_regs"
# returned is None or a dict with the fields:
#   "energy": energy used in nanojoules/instruction
#   "performance": in cpi (cycles/instruction)
#   "time": total user cpu time spent processing
#   "area": chip area in mm2
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
			"-P", prefix + "LQEntries=" + str(params["lq_size"]),
			"-P", prefix + "SQEntries=" + str(params["sq_size"]),
			"-P", prefix + "numPhysIntRegs=" + str(params["int_regs"]),
			"-P", prefix + "numPhysFloatRegs=" + str(params["float_regs"]),
			"-P", prefix + "numPhysVecRegs=" + str(params["vec_regs"]),
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
		args.log.write(" ".join(gem5_command) + "\n")
		with open(tmpdirname + "/gem5/log.log", "w") as log:
			with open(tmpdirname + "/gem5/err.log", "w") as err:
				process = subprocess.Popen(gem5_command, stdout=log, stderr=err)
				status = process.wait()

				if status != 0:
					args.log.write(f"Error during gem5 in {tmpdirname}: {status}\n")
					args.log.flush()
					return None

		# convert gem5 config/stats to mcpat input
		convert = [str(args.gem5tomcpat.absolute()),
			"--template", str(args.gem5tomcpat_template_warm if (params['cpt_id'] >= 0) else args.gem5tomcpat_template_cold),
			"--stats", tmpdirname + "/gem5/stats.txt",
			"--config", tmpdirname + "/gem5/config.json",
			"--output", tmpdirname + "/mcpat-in.xml",
		]
		args.log.write(" ".join(convert) + "\n")
		with open(tmpdirname + "/gem5tomcpat.log", "w") as log:
			with open(tmpdirname + "/gem5tomcpat.err", "w") as err:
				process = subprocess.Popen(convert, stdout=log, stderr=err)
				status = process.wait()

				if status != 0:
					args.log.write(f"Error during conversion in {tmpdirname}: {status}\n")
					args.log.flush()
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
		args.log.write(" ".join(mcpat_command) + "\n")
		with open(tmpdirname + "/mcpat.out", "w") as out:
			with open(tmpdirname + "/mcpat.err", "w") as err:
				process = subprocess.Popen(mcpat_command, stdout=out, stderr=err)
				status = process.wait()

				if status != 0:
					args.log.write(f"Error during mcpat in {tmpdirname}: {status}\n")
					args.log.flush()
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
		area = float(
			re.search(r"Area = (\d+\.\d+) mm", mcpat_report)
				.group(1)
		)

		# parse timing files to get total CPU user time spent processing this
		time_gem5 = float(re.search(r"(\d+\.\d+)user",
			open(tmpdirname + "/gem5.timing", "r").read()).group(1))
		time_mcpat = float(re.search(r"(\d+\.\d+)user",
			open(tmpdirname + "/mcpat.timing", "r").read()).group(1))

		# energy is in nanojoules, scale simtime
		energy = ((1000000000 * simtime) * (subthreshold_leakage + gate_leakage + runtime_dynamic)) / instructions
		return {"energy": energy, "performance": cpi, "time": (time_gem5 + time_mcpat), "area": area}

# run the jobs for a single simpoint set and calculate the weighted average single-threaded
# also calculates the baseline for this configuration too
# takes a dict with these fields
#   "rob_size": size of reorder buffer
#   "lq_size": size of load queue
#   "sq_size": size of store queue
#   "p_width": pipeline width
#   "interval": interval width to target
#   "int_regs", "float_regs", "vec_regs"
# returned is None or a dict with the fields:
#   "energy": energy used in nanojoules/instruction
#   "performance": in cpi (cycles/instruction)
#   "time": total user cpu time spent processing
#   "energy_baseline": energy value of the baseline
#   "performance_baseline": performance ""
#   "area": chip area in mm2
#   "area_baseline": "" of the baseline
def run_simpoint_set(params):
	# run each checkpoint
	checkpoint_dir = args.gem5_checkpoints / str(params["interval"])
	# map to gather results in
	result = {
		"energy": 0,
		"performance": 0,
		"time": 0,
		"area": 0,
	}
	for cpt_id, weight in weights[params["interval"]].items():
		subrun = {
			"cpt_id": cpt_id,
			"cpt_dir": checkpoint_dir,
			"rob_size": params["rob_size"],
			"lq_size": params["lq_size"],
			"sq_size": params["sq_size"],
			"p_width": params["p_width"],
			"int_regs": params["int_regs"],
			"float_regs": params["float_regs"],
			"vec_regs": params["vec_regs"],
		}

		subresult = run_gem5_mcpat(subrun)
		if subresult == None:
			return None

		result["energy"] += (subresult["energy"] * weight)
		result["performance"] += (subresult["performance"] * weight)
		result["time"] += subresult["time"]
		result["area"] += (subresult["area"] * weight)

	# do we need to run the baseline too?
	if params["interval"] == baseline:
		result["performance_baseline"] = result["performance"]
		result["energy_baseline"] = result["energy"]
		result["area_baseline"] = result["area"]
	else:
		baseline_params = dict(params)
		baseline_params["interval"] = baseline
		baseline_stats = run_simpoint_set(baseline_params)
		result["performance_baseline"] = baseline_stats["performance"]
		result["energy_baseline"] = baseline_stats["energy"]
		result["area_baseline"] = baseline_stats["area"]

	return result

# compute multiple simpoint metrics in parallel with passed in parameters, whilst logging process to a .csv
# takes a dictionary:
#   "rob_size": (array) size of reorder buffer
#   "lq_size": (array) size of load queue
#   "sq_size": (array) size of store queue
#   "p_width": (array) pipeline width
#   "interval": (array) interval width to use (this will always only be one value)
#   "int_regs", "float_regs", "vec_regs": (array) number of physical registers of each type
def run_parallel_gem5(base_params):
	curr = open("./curr", "r")
	curr_v = int(curr.read())
	curr.close()
	curr_v += 1
	args.log.write("curr: " + str(curr_v) + "\n")
	curr = open("./curr", "w")
	curr.write(str(curr_v))
	curr.close()

	args.log.write(str(base_params) + "\n")
	args.log.flush()

	exp_count = len(base_params["rob_size"])

	# unfold map of arrays into array of maps
	experiments = [{
		"rob_size": base_params["rob_size"][i],
		"lq_size": base_params["lq_size"][i],
		"sq_size": base_params["sq_size"][i],
		"p_width": base_params["p_width"][i],
		"interval": 16000000 if curr_v > 3 else 4000000,
		"int_regs": base_params["int_regs"][i],
		"float_regs": base_params["float_regs"][i],
		"vec_regs": base_params["vec_regs"][i],
	} for i in range(exp_count)]

	# get ordering value for reconstruction of best-found so far in R
	order = time.monotonic_ns()
	pool = multiprocessing.Pool(THREADS)
	result = None
	with pool:
		result = pool.map(run_simpoint_set, experiments)

	# log calculations to csv and refold array of maps into map of arrays
	# refold array of maps into map of arrays
	hypermapper_result = {
		"energy": [],
		"performance": [],
		"area": [],
	}
	for i in range(len(result)):
		args.data_out.write(f'{order},{experiments[i]["rob_size"]},{experiments[i]["lq_size"]},{experiments[i]["sq_size"]},{experiments[i]["p_width"]},{result[i]["energy"]},{result[i]["performance"]},{result[i]["time"]},{result[i]["energy_baseline"]},{result[i]["performance_baseline"]},{result[i]["area"]},{result[i]["area_baseline"]},{experiments[i]["int_regs"]},{experiments[i]["float_regs"]},{experiments[i]["vec_regs"]}\n')
		hypermapper_result["energy"].append(result[i]["energy"])
		hypermapper_result["performance"].append(result[i]["performance"])
		hypermapper_result["area"].append(result[i]["area"])
	args.data_out.flush()

	return hypermapper_result

args.data_out.write("order,rob_size,lq_size,sq_size,p_width,energy,performance,time,energy_baseline,performance_baseline,area,area_baseline,int_regs,float_regs,vec_regs\n")
args.data_out.flush()
hypermapper.optimizer.optimize("scenario.json", run_parallel_gem5)
