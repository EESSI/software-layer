#!/bin/bash
# This is a standard fake nvidia-smi script for testing purposes
# Using driver version 535.129.03 and CUDA version 8.0

# Check if --query-gpu flag is used
if [[ "$1" == "--query-gpu=gpu_name,count,driver_version,compute_cap" && "$2" == "--format=csv,noheader" ]]; then
    # Simulate output for a system with an NVIDIA A100 GPU
    echo "NVIDIA A100, 1, 535.129.03, 8.0"
    exit 0
else
    # Default output (similar to nvidia-smi with no arguments)
    cat << EOF
Mon Feb 26 10:30:45 2024       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.129.03   Driver Version: 535.129.03   CUDA Version: 12.2     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  NVIDIA A100          On  | 00000000:00:00.0 Off |                    0 |
| N/A   34C    P0    69W / 400W |      0MiB / 40960MiB |      0%      Default |
|                               |                      |             Disabled |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
EOF
    exit 0
fi
