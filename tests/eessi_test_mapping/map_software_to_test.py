import yaml
import re
import os
import argparse

def load_mappings(file_path):
    """Load the YAML mappings from a file."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Error: {file_path} does not exist.")
    with open(file_path, 'r') as file:
        config = yaml.safe_load(file)
    return config['mappings']

def read_software_names(file_path):
    """Read software names from the module_files.list.txt file."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Error: {file_path} does not exist.")
    with open(file_path, 'r') as file:
        software_names = [line.strip() for line in file if line.strip()]
    return software_names

def get_tests_for_software(software_name, mappings):
    """Get the list of tests for a given software name based on the first matching regex pattern."""
    
    # Iterate over patterns in the order they appear in the YAML file
    for pattern, tests in mappings.items():
        if re.match(pattern, software_name):
            return tests
    
    # If no matches are found, return the default tests if they exist
    if 'default_tests' in mappings:
        return mappings['default_tests']

    return []

def main(yaml_file, module_file, debug):
    """Main function to process software names and their tests."""
    mappings = load_mappings(yaml_file)
    if debug:
        print(f"Loaded mappings from '{yaml_file}'")

    software_names = read_software_names(module_file)
    if debug:
        print(f"Debug: Read software names from '{module_file}'")

    tests_to_run = []
    arg_string = ""
    for software_name in software_names:
        additional_tests = get_tests_for_software(software_name, mappings)
        for test in additional_tests:
            if test not in tests_to_run:
                tests_to_run.append(test)
        
        if additional_tests and debug:
            print(f"Software: {software_name} -> Tests: {additional_tests}")
        elif debug:
            print(f"Software: {software_name} -> No tests found")

        if tests_to_run:
            arg_string = " ".join([f"-n {test_name}" for test_name in tests_to_run])
            if debug:
                print(f"Full list of tests to run: {tests_to_run}")
                print(f"Argument string: {arg_string}")
        elif debug:
            print(f"Full list of tests to run: No tests found")

    # This is the main thing this script should return
    print(f"{arg_string}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Map software names to their tests based on a YAML configuration.")
    parser.add_argument('--mapping-file', type=str, help='Path to the YAML file containing the test mappings.')
    parser.add_argument('--module-list', type=str, help='Path to the file containing the list of software names.')
    parser.add_argument('--debug', action='store_true', help='Enable debug output.')
    
    args = parser.parse_args()
    
    main(args.mapping_file, args.module_list, args.debug)
