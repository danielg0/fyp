#!/bin/python3

# Python script that parses a simpoint points file, and runs all the
# corresponding checkpoints from a directory

import argparse
import os
import pathlib
import re
import sys
import subprocess
import multiprocessing

parser = argparse.ArgumentParser(
        prog = "Checkpoint Runner",
        description = "Given a simpoint points file, run all the corresponding checkpoints"
)

parser.add_argument(
        "--inPoints",
        type = argparse.FileType("r"),
        required = True,
)

parser.add_argument(
        "--checkpointdir",
        type = pathlib.Path,
        required = True,
)

parser.add_argument(
        "--outdir",
        type = pathlib.Path,
        required = True,
)

parser.add_argument(
        "--warmup",
        type = int,
        required = True,
)

parser.add_argument(
        "--width",
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

# traverse point list, determing mapping from simpoint id to checkpoint
simpoints = []
simpoint_line = re.compile(r"^(\d+) (\d+)\.(\d+)$")
simpoint_id = re.compile(r".+simpoint_(\d+)_.+")
for simpoint in args.inPoints.readlines():
    match = simpoint_line.match(simpoint)
    if match is None:
        print("Couldn't match line in in points: '" + simpoint + "'")
        sys.exit(-1)
    else:
        offset = int(match.group(1))
        cluster = match.group(2)
        index = match.group(3)

        # attempt to find matching unique checkpoint
        inst = str(max((offset * args.width) - args.warmup, 0))
        search = [f for f in args.checkpointdir.glob("cpt.*_inst_" + inst + "_*")]
        if len(search) == 0:
            print("Couldn't find checkpoint for: '" + simpoint + "'")
            sys.exit(-1)
        if len(search) > 1:
            print("Found more than one checkpoint: " + str(search))
            sys.exit(-1)
        checkpoint = search[0]

        # extract checkpoint id
        # make sure to add one
        match = simpoint_id.match(checkpoint.name)
        if match is None:
            print("Couldn't find id in '" + checkpoint.name + "'")
            sys.exit(-1)
        else:
            cpt_id = str(1 + int(match.group(1)))

            # checkpoints with no warmup won't work, handle them manually
            no_warmup = (offset * args.width) < args.warmup

            simpoints.append((cluster, index, cpt_id, no_warmup))

# method to measure a metric given a (cluster, index, cpt) tuple
def run_checkpoint(config):
    # increase oom score
    oom_score = open(f"/proc/{os.getpid()}/oom_score_adj", "w")
    oom_score.write("500")
    oom_score.close()

    cluster, index, cpt, no_warmup = config

    # create directory for output
    resultdir = args.outdir / cluster / index
    resultdir.mkdir(parents = True, exist_ok = True)

    # form command
    command = list(tuple(args.gem5cmd))
    command.insert(1, "--outdir")
    command.insert(2, str(resultdir))
    # if there's no warmup, run from the beginning manually as gem5 breaks on an
    # empty warmup
    if no_warmup:
        command.extend([
            "--maxinsts", str(args.width),
        ])
    else:
        command.extend([
            "--restore-simpoint-checkpoint",
            "-r", cpt,
            "--checkpoint-dir", str(args.checkpointdir),
        ])

    # timing
    command.insert(0, "/usr/bin/time")
    command.insert(1, "--output")
    command.insert(2, str(resultdir / "simulation.time"))

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
    pool.map(run_checkpoint, simpoints)
