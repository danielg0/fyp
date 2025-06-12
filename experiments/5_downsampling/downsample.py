#!/bin/python3

# copy an existing set of gem5 checkpoints and run an initial subset of them
# a gem5 checkpoint's length is configured by its folder name. By making a 
# symlink to that folder with a different name we can vary that parameter
#
# assumptions:
# --base-folder contains N checkpoints numbered from 0 to N-1
# --base-folder contains only checkpoint folders of the form cpt.simpoint_xx_inst_xx_weight_xx_interval_xx_warmup_xx/
# --base-folder won't change during the runtime of downsample.sh
# --base-folder contains no checkpoints with no warmup (ie. inst is 0 or less than warmup)

import argparse
import os
import pathlib
import re
import subprocess
import multiprocessing

parser = argparse.ArgumentParser(
	prog = "Truncated Checkpoint Runner",
	description = "Copy an existing set of gem5 checkpoints and run the initial N instructions of them",
)

parser.add_argument(
	"--base-folder",
	type = pathlib.Path,
	required = True,
)

parser.add_argument(
	"--base-width",
	type = int,
	required = True,
)

parser.add_argument(
	"--work-folder",
	type = pathlib.Path,
	required = True,
)

parser.add_argument(
	"--target-width",
	type = int,
	required = True,
)

parser.add_argument(
	"gem5cmd",
	type = str,
	nargs = "+",
)

args = parser.parse_args()
print(args)

(args.work_folder / "checkpoints").mkdir()

checkpoint_count = 0
checkpoint_nowarmup = []

# sort checkpoints to put in id order
checkpoints = list(args.base_folder.glob("cpt.*"))
checkpoints.sort()

# Count checkpoints and make symlinks to them with altered interval length
for checkpoint_dir in checkpoints:
	checkpoint_count += 1
	(args.work_folder / "checkpoints" / (checkpoint_dir.name.replace(f"_interval_{args.base_width}_", f"_interval_{args.target_width}_"))).symlink_to(checkpoint_dir.resolve())

	checkpoint_nowarmup.append(str(checkpoint_dir).endswith("warmup_0"))

# function for forming and running a gem5 checkpoint given an index
def run_checkpoint(index):
	# increase oom score
	oom_score = open("/proc/self/oom_score_adj", "w")
	oom_score.write("500")
	oom_score.close()

	# create directory for output
	resultdir = args.work_folder / str(index)
	resultdir.mkdir(parents = True, exist_ok = True)

	# form command
	command = list(tuple(args.gem5cmd))
	command.insert(1, "--outdir")
	command.insert(2, str(resultdir))
	# if there's no warmup run from beginning manually (gem5 breaks otherwise)
	if (checkpoint_nowarmup[index - 1]):
		command.extend([
			"--maxinsts", str(args.target_width),
		])
	else:
		command.extend([
			"--restore-simpoint-checkpoint",
			"-r", str(index),
			"--checkpoint-dir", str(args.work_folder / "checkpoints")
		])

	# timing
	command.insert(0, "/usr/bin/time")
	command.insert(1, "--output")
	command.insert(2, str(resultdir / "truncate.timing"))

	with open(resultdir / "log.log", "w") as log:
		with open(resultdir / "err.log", "w") as err:
			print(command)

			process = subprocess.Popen(command, stdout=log, stderr=err)
			status = process.wait()

			if status != 0:
				print("Exited with status code " + str(status))

# create a set of jobs to measure metrics for each checkpoint
pool = multiprocessing.Pool(1)
with pool:
	# recall gem5 one indexes checkpoints even though they are named zero-indexed
	pool.map(run_checkpoint, range(1, checkpoint_count + 1))
