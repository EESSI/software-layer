import os
import re
import requests
import json


def get_easyconfig_filename(module_name):
    """Generates the expected EasyConfig filename based on the module name."""
    return f"{module_name.replace('/', '-')}.eb"


def get_easyconfig_url(module_name):
    """Constructs the GitHub raw URL for the EasyConfig file."""
    easyconfig_filename = get_easyconfig_filename(module_name)
    first_letter = module_name[0].lower()
    base_url = "https://raw.githubusercontent.com/easybuilders/easybuild-easyconfigs/develop/easybuild/easyconfigs"
    return f"{base_url}/{first_letter}/{module_name.split('/')[0]}/{easyconfig_filename}"


def extract_homepage_or_source(easyconfig_url, module_name):
    """Fetches the EasyConfig file and extracts the homepage or source URL."""
    try:
        response = requests.get(easyconfig_url)
        response.raise_for_status()
        content = response.text

        homepage_match = re.search(r"homepage\s*=\s*['\"](.*?)['\"]", content)
        source_match = re.search(
            r"source_urls\s*=\s*\[['\"](.*?)['\"]\]", content)

        homepage = homepage_match.group(1) if homepage_match else "N/A"
        source_url = source_match.group(1) if source_match else "N/A"

        match = re.match(r"^(.*?)/([\d\.]+)-.*$", module_name)
        if match:
            name, version = match.groups()
            version_parts = version.split('.')
            version_major = version_parts[0] if len(version_parts) > 0 else ""
            version_major_minor = '.'.join(version_parts[:2]) if len(version_parts) > 1 else ""
            nameletter = name[0] if name else ""
            namelower = name.lower()

                        # Replace placeholders
            for placeholder, value in {
                "%(name)s": name,
                "%(namelower)s": namelower,
                "%(version)s": version,
                "%(version_major)s": version_major,
                "%(version_major_minor)s": version_major_minor,
                "%(nameletter)s": nameletter,
            }.items():
                homepage = homepage.replace(placeholder, value)
                source_url = source_url.replace(placeholder, value)

        return homepage, source_url
    except requests.RequestException:
        return "N/A", "N/A"


def process_modules(module_list):
    """Processes a list of modules to retrieve homepage and source URLs."""
    results = []

    for module in module_list:
        easyconfig_url = get_easyconfig_url(module)
        homepage, source_url = extract_homepage_or_source(easyconfig_url, module)

        results.append({
            "Module": module,
            "EasyConfig URL": easyconfig_url,
            "Homepage": homepage,
            "Source URL": source_url
        })

    return results


def load_modules_from_file(filename):
    """Loads module names from a text file."""
    with open(filename, "r") as f:
        return [line.strip() for line in f if line.strip()]


def main():
    
    filename = os.sys.argv[1] if len(os.sys.argv) > 1 else "missing_modules.txt"  # Default filename

    if not os.path.exists(filename):
        print(f"Error: {filename} not found.")
        return

    module_list = load_modules_from_file(filename)
    results = process_modules(module_list)

    # Save results to a JSON file
    output_file = "modules_results.json"  # Output file to store results

    with open(output_file, "w") as f:
        json.dump(results, f, indent=4)

    print(f"Results saved to {output_file}")


if __name__ == "__main__":
    main()
