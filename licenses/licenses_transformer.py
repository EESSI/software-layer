#!/usr/bin/env python3

import yaml
from collections import defaultdict

infile = "licenses.yaml"
outfile = "licenses.yml"

with open(infile, "r") as f:
    data = yaml.safe_load(f)

# Nested dict: {software: {version: info}}
result = {}

for full_key, info in data.items():
    # Example full_key: "ALL/0.9.2-foss-2023a"
    try:
        software, rest = full_key.split("/", 1)
    except ValueError:
        # If no '/', skip or handle differently
        # For now just continue
        print(f"Skipping key without '/': {full_key}")
        continue

    # Split the version from the toolchain suffix
    # "0.9.2-foss-2023a" -> version="0.9.2"
    version = rest.split("-", 1)[0]

    # Ensure nested structure exists
    if software not in result:
        result[software] = {}
    if version in result[software]:
        # Optional: warn if we’re overwriting same software/version
        print(f"Warning: duplicate entry for {software} {version}, overwriting.")

    result[software][version] = info

with open(outfile, "w") as f:
    yaml.safe_dump(result, f, sort_keys=True)
