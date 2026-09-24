#!/usr/bin/env python3
# Check that all supported CPU targets have been successfully built, based on
# the bot's status table in the PR comment.
#
# Usage: check_builds.py
#   Reads PR_NUMBER and COMMENT_BODY from environment variables.
#   No API calls required — the triggering comment body is already available.
#
# Exit codes:
#   0: Success (all supported targets have successful builds, or mapping is empty)
#   1: Failure (missing/failed builds, or commit SHA inconsistency)

import datetime
import os
import sys
import re


# ============================================================================
# TODO: FILL IN THE SUPPORTED CPU TARGETS PER REPO
# ============================================================================
# This mapping defines which CPU targets (values of the 'for' column) must be
# successfully built for each repository (value of the 'repo' column).
# The values below are a placeholder — please fill in the actual supported
# targets for your repositories.
#
# Example structure:
# SUPPORTED_TARGETS = {
#     "eessi.io-2025.06-software": [
#         "x86_64/amd/zen2",
#         "x86_64/amd/zen3",
#         "x86_64/amd/zen4",
#         "x86_64/intel/haswell",
#         # ... add all supported targets for this repo ...
#     ],
#     "eessi.io-2023.06-software": [
#         # ... supported targets for 2023.06 ...
#     ],
# }
# ============================================================================
SUPPORTED_TARGETS = {
    # Placeholder — fill in your supported targets here
    # "eessi.io-2025.06-software": ["x86_64/amd/zen2"],
}


def parse_date(date_str):
    """
    Parse a date string like 'Aug 04 18:11:14 UTC 2026' into a datetime object.
    Returns None if parsing fails.
    """
    try:
        return datetime.datetime.strptime(date_str, "%b %d %X %Z %Y")
    except ValueError:
        return None


def parse_markdown_table(body):
    """
    Parse the bot's status table from the comment body.
    Returns a list of dicts, one per row, with column names as keys.
    Uses header-driven parsing (column names from the header row) so it
    tolerates extra/missing columns like 'commit SHA'.
    """
    marker = "This is the status of all the `bot: build` commands:"
    if marker not in body:
        return None

    # Find the table: start from the marker line, look for header row
    lines = body.splitlines()
    header_idx = None
    for i, line in enumerate(lines):
        if line.startswith("|on|"):
            header_idx = i
            break

    if header_idx is None:
        return None

    # Parse header row
    header_line = lines[header_idx]
    # Split by | and strip whitespace, remove empty first/last from leading/trailing |
    columns = [c.strip() for c in header_line.strip("|").split("|")]

    # Find separator row (line of dashes)
    separator_idx = header_idx + 1
    while separator_idx < len(lines) and not lines[separator_idx].startswith("|"):
        separator_idx += 1
    if separator_idx >= len(lines):
        return None

    # Parse data rows
    rows = []
    for line in lines[separator_idx + 1:]:
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) != len(columns):
            continue
        row = dict(zip(columns, cells))
        # Strip backticks from 'on' and 'for' values
        for key in ["on", "for"]:
            if key in row:
                row[key] = row[key].strip("`")
        rows.append(row)

    return rows


def dedup_by_for_repo(rows):
    """
    Deduplicate rows by (for, repo) pair, keeping only the last build
    (by date) for each pair.
    Returns a dict: (for, repo) -> row
    """
    latest = {}
    for row in rows:
        key = (row.get("for"), row.get("repo"))
        if key == (None, None) or key[0] is None:
            continue
        date_str = row.get("date", "")
        date = parse_date(date_str)
        if date is None:
            # Treat as oldest if date can't be parsed
            date = datetime.datetime.min
        if key not in latest or date > latest[key][0]:
            latest[key] = (date, row)
    return {k: v[1] for k, v in latest.items()}


def main():
    pr_number = os.environ.get("PR_NUMBER")
    comment_body = os.environ.get("COMMENT_BODY")

    if not pr_number or not comment_body:
        print("ERROR: PR_NUMBER and COMMENT_BODY must be set in environment")
        sys.exit(1)

    # Parse the table
    rows = parse_markdown_table(comment_body)
    if rows is None:
        print("ERROR: Could not find status table in comment")
        sys.exit(1)

    if not rows:
        print("ERROR: Status table is empty")
        sys.exit(1)

    # Deduplicate by (for, repo)
    deduped = dedup_by_for_repo(rows)
    if not deduped:
        print("ERROR: No valid builds found in table")
        sys.exit(1)

    # Determine which repos are present in both table and mapping
    table_repos = set(row.get("repo") for row in deduped.values() if row.get("repo"))
    mapping_repos = set(SUPPORTED_TARGETS.keys())
    repos_to_check = table_repos & mapping_repos

    # Warn if repos in table are missing from mapping
    for repo in table_repos - mapping_repos:
        print(f"WARNING: Repo '{repo}' found in table but not in SUPPORTED_TARGETS mapping; skipping checks for this repo")

    # Check commit SHA consistency across all deduplicated builds (if column present)
    commit_shas = set()
    for row in deduped.values():
        sha = row.get("commit SHA")
        if sha:
            commit_shas.add(sha)

    if len(commit_shas) > 1:
        print("ERROR: Commit SHA inconsistency detected across builds")
        for sha in commit_shas:
            matching_rows = [r for r in deduped.values() if r.get("commit SHA") == sha]
            targets = [r.get("for") for r in matching_rows]
            print(f"  SHA {sha}: targets {targets}")
        print("All builds must reference the same commit SHA.")
        sys.exit(1)

    # Verify each supported target for each repo
    failed = False
    for repo in repos_to_check:
        supported = SUPPORTED_TARGETS[repo]
        print(f"\nChecking repo: {repo}")
        builds_for_repo = {k: v for k, v in deduped.items() if v.get("repo") == repo}

        for target in supported:
            key = (target, repo)
            row = deduped.get(key)
            if row is None:
                print(f"  FAIL: Target '{target}' not found in builds for {repo}")
                failed = True
                continue

            status = row.get("status", "").strip()
            result = row.get("result", "")
            if status != "finished" or "SUCCESS" not in result:
                print(f"  FAIL: Target '{target}' is not SUCCESS/finished")
                print(f"    status={status}, result={result}")
                if row.get("url"):
                    print(f"    URL: {row['url']}")
                failed = True
            else:
                print(f"  OK: Target '{target}' built successfully")

    # Check if mapping is empty
    if not mapping_repos:
        print("\nWARNING: SUPPORTED_TARGETS mapping is empty — no checks performed.")
        print("Please populate SUPPORTED_TARGETS in check_builds.py with your supported targets.")

    if failed:
        print("\nERROR: Build verification failed. Please fix the above issues.")
        sys.exit(1)

    print("\nSUCCESS: All supported targets have been successfully built.")
    sys.exit(0)


if __name__ == "__main__":
    main()
