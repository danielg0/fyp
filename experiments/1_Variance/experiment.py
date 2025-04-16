#!/bin/python

import multiprocessing
import os
import subprocess
import time

# paths
BUILDS = "/home/danielg/Builds/"
GEM5 = BUILDS + "Git/gem5/"
GEM5_BIN = GEM5 + "build/X86/gem5.opt"
SIMPOINT = BUILDS + "Local/simpoint/bin/simpoint"
COREMARK = BUILDS + "Git/coremark-pro/builds/linux64/gcc64/bin/"

# coremark benchmarks
coremark_benchmarks = {
        "cjpeg" : "cjpeg-rose7-preset.exe",
        "core" : "core.exe",
        "linear" : "linear_alg-mid-100x100-sp.exe",
        "loops" : "loops-all-mid-10k-sp.exe",
        "nnet": "nnet_test.exe",
        "parser" : "parser-125k.exe",
        "radix2" : "radix2-big-64k.exe",
        "sha" : "sha-test.exe",
        "zip" : "zip-test.exe"
}

# TODO: determine what these do
coremark_args = ["-v0", "-c1", "-w1", "-i1"]

if not os.path.exists("out"):
    os.makedirs("out")

# for each benchmark:
# - generate bbvs
# - super sample
# - run simpoint
# - collect the 10 closest intervals for each cluster

jobs = []
for bench, path in coremark_benchmarks.items():
    print("-- " + bench + " --")

    result_dir = "out/" + bench
    if not os.path.exists(result_dir):
        os.makedirs(result_dir)

    run_command = [
        GEM5_BIN,
        "--outdir=" + result_dir,
        GEM5 + "/configs/deprecated/example/se.py",
        "-c", COREMARK + path,
        "--options=" + " ".join(coremark_args),

        "--simpoint-profile",
        "--simpoint-interval", "10000",

        "--cpu-type=AtomicSimpleCPU",
        "--mem-size=8GiB",
        "--caches",
        "--l2cache",
        "--l1d_size=64KiB",
        "--l1i_size=64KiB",
        "--l2_size=1MB",
    ]

    jobs.append((run_command, result_dir))

# run a job from the queue
def exec_gem5(job):
    run_command, result_dir = job

    with open(result_dir + "/run.log", "w+") as log:
        with open(result_dir + "/err.log", "w+") as error:
            start = str(time.time()) + ": " + ' '.join(run_command)
            log.write(start)
            error.write(start)
            process = subprocess.Popen(run_command, stdout=log, stderr=error)

            status = process.wait()
            print(result_dir + " exited with exit code " + str(status))

pool = multiprocessing.Pool(10)
with pool:
    pool.map(exec_gem5, jobs)

print("Done")
