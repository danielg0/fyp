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
        required = True,
)

parser.add_argument(
        "-inWeights",
        type = argparse.FileType("r"),
        required = True,
)

parser.add_argument(
        "-outPoints",
        type = argparse.FileType("w"),
        required = True,
)

parser.add_argument(
        "-outWeights",
        type = argparse.FileType("w"),
        required = True,
)

args = parser.parse_args()
# map of cluster to its weight
weights = {}
# map of arrays: cluster -> [(distance, bbv index)]
points = {}

weight = re.compile(r"^([+\-e.0-9]+) (\d+)$")
# gather cluster weights
for line in args.inWeights:
    match = weight.match(line)
    if match is None:
        print("Error: couldn't parse weight '" + line + "'")
        sys.exit(-1)
    else:
        weighting = float(match.group(1))
        cluster = int(match.group(2))
        weights[cluster] = weighting

# regex to match a integer and float (might be of form 0.43e+34)
label = re.compile(r"^(\d+) ([+\-e.0-9]+)$")
# track index of current line
i = 0
for line in args.inLabels:
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

    candidates = min(args.N, len(sorted_points))
    point_weight = weights[key] / candidates
    for i in range(candidates):
        distance, index = sorted_points[i]
        point_name = str(key) + "." + str(i)
        args.outPoints.write(str(index) + " " + point_name + "\n")
        args.outWeights.write(str(point_weight) + " " + point_name + "\n")
