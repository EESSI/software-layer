import os, yaml

yml_file = os.sys.argv[1]
new_dict = {}
with open(yml_file, "r") as f:
    licenses_data = yaml.safe_load(f)
    for key, details in licenses_data.items():
        if '/' in key:
            software_name, version = key.split('/',1)
            if software_name not in new_dict:
                new_dict[software_name] = {}
            new_dict[software_name][version] = details
    
output_file = 'reformatted_licenses.yaml'
with open(output_file, 'w') as new_file:
    yaml.dump(new_dict, new_file)