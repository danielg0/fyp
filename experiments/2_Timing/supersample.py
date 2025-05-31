#!/bin/python3

# combine neighbouring bbvs

import argparse
import os
import pathlib
import re
import sys

parser = argparse.ArgumentParser(
        prog = "SimPoint Supersampler",
        description = "Supersamples sets of SimPoint BBVs, combining intervals together"
) 

parser.add_argument(
        "--infile",
        type = argparse.FileType("r"),
        default = sys.stdin,
        help = "Input text basic-block vector (BBV) file",
)
parser.add_argument(
        "--insize",
        type = int,
        help = "Size of intervals in the input file. We recommend you specify this when you know, as Gem5 outputs BBVs of varying sizes around the target interval size. If not given, will be calculated from the BBV itself."
) 
parser.add_argument(
        "--outdir",
        type = pathlib.Path,
        default = pathlib.Path("."),
)
parser.add_argument(
        "--scaleto",
        type = int,
        nargs="+",
        default = [10000, 100000, 1000000, 10000000],
)

args = parser.parse_args()

if args.insize is None:
    print("Warning: interval size of input BBVs not specified, will be calculated")

# track instructions remaining til next bbv export
instr_left = []
# next_bbv stores partial bbvs as they're being combined
next_bbv = []
for scale in args.scaleto:
    instr_left.append(scale)
    next_bbv.append({})

outfiles = [open(str(args.outdir) + "/" + str(n) + ".bb", "w") for n in args.scaleto]

for bbv in args.infile:
    if not bbv.strip().startswith('T'):
        print("Comment line: " + bbv)
        continue

    bbv_terms = re.findall(r":(\d+):(\d+)(?:\s|$)", bbv)
    for bb_index, instr_count in [(a, int(b)) for (a, b) in bbv_terms]:
        for i in range(len(args.scaleto)):
            if bb_index in next_bbv[i]:
                next_bbv[i][bb_index] += instr_count
            else:
                next_bbv[i][bb_index] = instr_count

            # if insize not given, determine from instr_count
            # its better to specify insize as gem5 doesn't produce bbvs of constant width
            if args.insize is None:
                instr_left[i] -= instr_count

    # determine whether we have a full bbv to output
    for i in range(len(args.scaleto)):
        if args.insize is not None:
            instr_left[i] -= args.insize

        if instr_left[i] <= 0:
            out = ' '.join([":" + index + ":" + str(count) for index, count in next_bbv[i].items()])
            # trailing space on each line to match gem5 output
            outfiles[i].write("T" + out + " \n")

            # clear structures for next bbv
            instr_left[i] = args.scaleto[i]
            next_bbv[i] = {}

for file in outfiles:
    file.close()
