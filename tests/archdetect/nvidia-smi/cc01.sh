#!/bin/bash
# output from non-existing NVIDIA GPU system,
# to test handling of unknown GPU model
# (supposedly) produced by: nvidia-smi --query-gpu=gpu_name,count,driver_version,compute_cap --format=csv,noheader
echo "NVIDIA does-not-exist, 1, 000.00.00, 0.1"
exit 0
