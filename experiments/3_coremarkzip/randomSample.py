#!/bin/python3
import argparse
import multiprocessing
import pathlib
import random
import re
import subprocess

parser = argparse.ArgumentParser(
	prog = "Random sample experiment",
	description = "Run 30 random checkpoints collected and measure metrics",
)

parser.add_argument(
	"--checkpoint-dir",
	type=pathlib.Path,
	required=True,
)

parser.add_argument(
	"--outdir",
	type = pathlib.Path,
	required = True,
)

parser.add_argument(
	"--warmup",
	type=int,
	required=True,
)

parser.add_argument(
	"--jobs",
	type=int,
	default=6,
)

parser.add_argument(
	"gem5cmd",
	type = str,
	nargs = "+",
)

args = parser.parse_args()

# iso-formatted deadline day
SEED=20250613
random.seed(SEED)

# number of points to simulate for each interval size
# pick 30 so central limit theorem applies
samples = 30

# the set of interval sizes to test with
# guesstimate something that'll be close to simpoint in terms of execution time
# simpoint uses ~10 points per interval, use ~1/3rd of simpoint interval sizes
intervals = [41500, 83000, 166000, 332000, 664000, 1328000, 2656000, 5312000]

# get the checkpoints we sample from
# find all non-empty checkpoint directories in the path we were given
# we sort the list because that's what gem5 does
checkpoints = list(map(lambda x: x.parent, args.checkpoint_dir.glob("cpt.*/m5.cpt")))
checkpoints.sort()
if len(checkpoints) < samples:
	print("Error: only " + str(len(checkpoints)) + " checkpoints, not enough for " + str(samples) + " samples")
	exit(-1)

# randomly pick the 30 samples to use for each interval size
experiment = {}
for interval in intervals:
	experiment[interval] = random.sample(range(len(checkpoints)), k=samples)

# function for running a particular checkpoint for a given (checkpoint_index, interval, sample_index) tuple
def run_checkpoint(config):
	# increase oom score
	oom_score = open("/proc/self/oom_score_adj", "w")
	oom_score.write("500")
	oom_score.close()

	checkpoint_index, interval, sample_index = config

	# create output directory
	resultdir = args.outdir / str(interval) / str(sample_index)
	resultdir.mkdir(parents = True, exist_ok = True)

	# form command, adding on time tracking
	timing = [
		"/usr/bin/time",
		"-o", str(resultdir / "random.time"),
	]

	command = list(tuple(args.gem5cmd))
	command.insert(1, "--outdir")
	command.insert(2, str(resultdir))

	command.extend([
		"--checkpoint-dir", str(args.checkpoint_dir),
		# DON'T FORGET GEM5 COUNTS WEIRD
		"-r", str(checkpoint_index + 1),
		"--standard-switch", "-1",
		"--warmup-insts", str(args.warmup),
		"--maxinsts", str(interval),
	])
	timing.extend(command)

	with open(resultdir / "log.log", "w") as log:
		with open(resultdir / "err.log", "w") as err:
			print(timing)

			process = subprocess.Popen(timing, stdout=log, stderr=err)
			status = process.wait()

			if status != 0:
				print("Exited with status code " + str(status))	

# create a set of jobs
jobs = []
for interval in intervals:
	print(str(interval) + ":")
	for sample in range(len(experiment[interval])):
		print("\t" + str(sample) + ": " + str(checkpoints[experiment[interval][sample]]))
		jobs.append((experiment[interval][sample], interval, sample))

pool = multiprocessing.Pool(args.jobs)
with pool:
	pool.map(run_checkpoint, jobs)
