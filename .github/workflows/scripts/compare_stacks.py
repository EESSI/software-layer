import argparse
import os
import re
import glob
import json


def parse_module_file(module_file_path):
    """
    Extracts module name, version, and extensions from a module file.
    """
    module_name = os.path.basename(os.path.dirname(module_file_path))
    version = os.path.basename(module_file_path)

    try:
        with open(module_file_path, "r") as file:
            content = file.read()

        # Extract extensions from content using regex
        match = re.search(r'extensions\("(.+)"\)', content)
        extensions = []

        if match:
            # Split the list of packages by commas
            packages = match.group(1)
            for pkg in packages.split(","):
                parts = pkg.split("/")

                # Check if the package is in the name/version format
                if len(parts) == 2:
                    extensions.append((parts[0], parts[1]))
                elif len(parts) == 1:
                    extensions.append((parts[0], "none"))
                else:
                    print(f"Warning: Skipping invalid package format: {pkg}")

        return {(module_name, version): tuple(extensions)}

    except Exception as e:
        print(f"Error parsing module file {module_file_path}: {e}")
        return {(module_name, version): ()}


def get_available_modules(base_dir):
    """
    Get the list of modules from all subdirectories inside the specified base directory.
    """
    try:
        modules = {}
        # Only look for .lua files
        for module_path in glob.glob(os.path.join(base_dir, "*/*.lua")):
            modules.update(parse_module_file(module_path))
        return modules

    except Exception as e:
        print(f"Error retrieving modules from {base_dir}: {e}")
        return {}


def compare_stacks(dir1, dir2):
    """
    Compare two sets of Lmod module files, including versions and extensions.
    """
    modules1 = get_available_modules(dir1)
    modules2 = get_available_modules(dir2)

    # Find differences between the two dictionaries
    modules_removed = set(modules1.keys()) - set(modules2.keys())
    modules_added = set(modules2.keys()) - set(modules1.keys())
    matching_keys = set(modules1.keys()) & set(modules2.keys())

    diff_results = {
        "module_differences": {
            "missing": list("/".join(module) for module in modules_removed),
            "added": list("/".join(module) for module in modules_added),
        },
        "extension_differences": [],
    }

    # Compare extensions for matching keys
    for key in matching_keys:
        if modules1[key] != modules2[key]:
            diff_results["extension_differences"].append(
                {
                    "/".join(key): {
                        "missing": list(
                            "/".join(key)
                            for key in list(set(modules1[key]) - set(modules2[key]))
                        ),
                        "added": list(
                            "/".join(key)
                            for key in list(set(modules2[key]) - set(modules1[key]))
                        ),
                    }
                }
            )

    return diff_results


def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description="Compare two Lmod module directories")
    parser.add_argument("path1", type=str, help="The first directory path")
    parser.add_argument("path2", type=str, help="The second directory path")

    # Parse the arguments
    args = parser.parse_args()

    # Validate the paths
    for path in [args.path1, args.path2]:
        if not os.path.exists(path):
            print(f"Warning: Path does not exist: {path}")

    # Compare the stacks
    diff_results = compare_stacks(args.path1, args.path2)

    # Print the differences
    if any(
        [
            diff_results["module_differences"]["missing"],
            diff_results["module_differences"]["added"],
            diff_results["extension_differences"],
        ]
    ):
        print(json.dumps(diff_results, indent=2))
        exit(1)


if __name__ == "__main__":
    main()
