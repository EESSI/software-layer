import yaml
import re
import os

def load_mappings(file_path):
    """Load the YAML mappings from a file."""
    with open(file_path, 'r') as file:
        config = yaml.safe_load(file)
    return config['mappings']

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

def read_software_names(file_path):
    """Read software names from the module_files.list.txt file."""
    with open(file_path, 'r') as file:
        software_names = [line.strip() for line in file if line.strip()]
    return software_names

if __name__ == "__main__":
    mappings = load_mappings("software_to_tests.yml")
    
    # Check if the file module_files.list.txt exists
    module_file_path = "module_files.list.txt"
    if not os.path.exists(module_file_path):
        print(f"Error: {module_file_path} does not exist.")
    else:
        software_names = read_software_names(module_file_path)
        tests_to_run = []
        for software_name in software_names:
            additional_tests = get_tests_for_software(software_name, mappings)
            for test in additional_tests:
                if test not in tests_to_run:
                    tests_to_run.append(test)
            
            if additional_tests:
                print(f"Software: {software_name} -> Tests: {additional_tests}")
            else:
                print(f"Software: {software_name} -> No tests found")

            if tests_to_run:
                arg_string = " ".join([f"-n {test_name}" for test_name in tests_to_run])
                print(f"Full list of tests to run: {tests_to_run}")
                print(f"Argument string: {arg_string}")
            else:
                print(f"Full list of tests to run: No tests found")
