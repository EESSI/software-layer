import yaml

def reformat_extension_licenses():
    with open('licenses/extension_licenses.yaml', 'r') as f:
        modules = yaml.safe_load(f)
    
    results = {}
    for module in modules:
        module_name,version = module.split('/',1)   

        if '-' in version:
            version,toolchain = version.split('-',1)
        
        # If the module_name is not yet in results, create an empty dictionary for it
        if module_name not in results:  
            results[module_name] = {}

        # Save original module content under results[module_name][version]
        results[module_name][version] = modules[module]

    with open('licenses/extension_licenses_mod.yaml', 'w') as f2:
        yaml.dump(results, f2, default_flow_style=False, sort_keys=True)

    return

reformat_extension_licenses()
