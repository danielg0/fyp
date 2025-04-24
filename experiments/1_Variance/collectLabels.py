#!/bin/python3

# collect the N closest simpoints to a centre for each group

import argparse
import pathlib
import re
import sys

parser = argparse.ArgumentParser(
        prog = "SimPoint Gatherer",
        description = "Gather the N points closest to each SimPoint cluster's centre"
)

parser.add_argument(
        "-N",
        type = int,
        default = 10,
        help = "Number of points to pick for each cluster",
)

parser.add_argument(
        "-inLabels",
        type = argparse.FileType("r"),
        default = sys.stdin,
)

parser.add_argument(
        "-outPoints",
        type = argparse.FileType("w"),
        required = True,
)

args = parser.parse_args()
# map of arrays: cluster -> [(distance, bbv index)]
points = {}

# regex to match a integer and float (might be of form 0.43e+34)
label = re.compile(r"^(\d+) ([+\-e.0-9]+)$")
# track index of current line
i = 0
for line in args.inLabels.readlines():
    match = label.match(line)
    if match is None:
        print("Warning: Didn't match line '" + line + "'")
        continue
    else:
        cluster = int(match.group(1))
        distance = float(match.group(2))

        if cluster in points:
            points[cluster].append((distance, i))
        else:
            points[cluster] = [(distance, i)]
        i += 1

# output 10 closest points for each cluster
for key in sorted(points):
    sorted_points = sorted(points[key])
    if len(sorted_points) < args.N:
        print("Warning: Less than N points for cluster " + str(key))
    for i in range(min(args.N, len(sorted_points))):
        distance, index = sorted_points[i]
        args.outPoints.write(str(index) + " " + str(key) + "." + str(i) + "\n")
