import requests
import json
import os
import re
import argparse
import yaml
import shutil
from urllib.parse import quote
from bs4 import BeautifulSoup

# API Endpoints
URL_REPO = "https://repos.ecosyste.ms/api/v1/repositories/lookup?url="
URL_REG = "https://packages.ecosyste.ms/api/v1/packages/lookup?repository_url="

# Constants
MAX_DEPTH = 3

# Global variable
DEBUG_MODE = False

# Load SPDX License Data to interpolate with found license files
with open("licenses/spdx-list.json", "r") as f:
    spdx_data = json.load(f)
SPDX_LICENSES = {
    entry["licenseId"].lower(): {
        "id": entry["licenseId"],
        "name": entry["name"], 
        "isOsiApproved": entry.get("isOsiApproved", False),
        "isFsfLibre": entry.get("isFsfLibre", False)
    }
    for entry in spdx_data["licenses"]
}

def clean_repo_url(url):
    """Removes unnecessary parts like /archive/, /releases/, and .git from repo URLs."""
    url = re.sub(r"/(archive|releases|tags|download)/.*$", "", url)
    return re.sub(r"\.git$", "", url)

def is_valid_repo_url(url):
    """Checks if the URL is a valid GitHub/GitLab repository."""
    return re.match(r"https?://(github|gitlab)\.com/[^/]+/[^/]+/?$", url)

def fetch_license_from_ecosystems(url, depth=0):
    """Fetches license information from ecosyste.ms API with a depth limit."""
    if depth > MAX_DEPTH:
            if DEBUG_MODE:
                print(f"Max depth reached for {url}, stopping recursion.")
            return "not found", "not found"

    clean_url = clean_repo_url(url)
    formatted_url = quote(clean_url, safe="")
    if DEBUG_MODE:
        print(f"Depth {depth}: Checking {url}")

    try:
        repo_response = requests.get(f"{URL_REPO}{formatted_url}")
        reg_response = requests.get(f"{URL_REG}{formatted_url}")
    except requests.RequestException as e:
        if DEBUG_MODE:
            print(f"Request failed: {e}")
        return "not found", "not found"

    if repo_response.status_code == 200:
        data = repo_response.json()
        license_info = data.get("license", "not found")
        repo_url = data.get("repository_url", "not found")
        
        if license_info in ("not found", "other", "Other"):
            scraped_license = scrape_license(clean_url)
            if DEBUG_MODE:
                print("SCRAPED LICENSE "+str(scraped_license))
            if scraped_license != "not found":
                return scraped_license[0], scraped_license[1]
        
        return license_info, repo_url

    if reg_response.status_code == 200:
        data = reg_response.json()
        if DEBUG_MODE:
            print(f"for {URL_REG}{formatted_url}")
        if isinstance(data, list) and data:
            license_info = data[0].get("normalized_licenses", "not found")
            repo_url = data[0].get("repository_url", "not found")
            if license_info in ("not found", "other", "Other"):
                scraped_license = scrape_repo_from_package(clean_url, depth + 1)
                if DEBUG_MODE:
                    print("SCRAPED LICENSE "+str(scraped_license))
                if scraped_license != "not found":
                    return scraped_license[0], scraped_license[1]
                    
            return license_info, repo_url
        else: 
            scraped_license = scrape_license(clean_url)
            if DEBUG_MODE:
                print("SCRAPED LICENSE "+str(scraped_license))
            if scraped_license != "not found":
                return scraped_license, scraped_license[1]
            
    return scrape_repo_from_package(clean_url, depth + 1)

#def scrape_license(repo_url):
#    try:
#        response = requests.get(repo_url)
#        response.raise_for_status()
#    except requests.RequestException:
#        return "not found"
    
#    soup = BeautifulSoup(response.text, "html.parser")
#    for link in soup.find_all("a", href=True):
#        if re.search(r"license|copying|copyright|legal", link.text, re.IGNORECASE):
#            license_url = requests.compat.urljoin(repo_url, link["href"])
#            license_text = requests.get(license_url).text.lower()
#            print(str(license_text))
#            for spdx_id, content in SPDX_LICENSES.items():
#                print("spdx_id: "+spdx_id)
#                print("name: "+content.get("name"))
#                if spdx_id or content.get("name") in license_text:
#                    return spdx_id, license_url
#                if "GNU General Public License" in license_text: 
#                    return "GPL-3.0", license_url
#            return "not found", license_url
#    return "not found"

def scrape_license(repo_url):
    try:
        response = requests.get(repo_url)
        response.raise_for_status()
    except requests.RequestException:
        return "not found"

    soup = BeautifulSoup(response.text, "html.parser")

    # Step 1: Find the license file URL
    license_url = None
    for link in soup.find_all("a", href=True):
        if re.search(r"license|copying|copyright|legal", link.text, re.IGNORECASE):
            license_url = requests.compat.urljoin(repo_url, link["href"])
            break

    if not license_url:
        return "not found"

    # Step 2: Handle the license file content based on the platform
    if "github.com" in repo_url:
        # GitHub specific handling
        # Convert the GitHub blob URL to a raw URL
        license_url = license_url.replace("/blob/", "/raw/")
    elif "gitlab.com" in repo_url or "gitlab." in repo_url:  # Custom GitLab instances
        # GitLab specific handling
        # Convert the GitLab blob URL to a raw URL
        license_url = license_url.replace("/blob/", "/raw/")

    # Step 3: Fetch and process the license file content
    try:
        license_response = requests.get(license_url)
        license_response.raise_for_status()
        license_text = license_response.text.lower()

        # Step 4: Match the license text against SPDX licenses
        for spdx_id, content in SPDX_LICENSES.items():
            if  content.get("name").lower() in license_text:
                return spdx_id, license_url
        if "general public license" in license_text:
            return "GPL-3.0", license_url
        return "not found", license_url
    except requests.RequestException:
        return "not found", "not found"

def scrape_repo_from_package(url, depth=0):
    """Scrapes a package homepage for a GitHub/GitLab repository link."""
    if depth > MAX_DEPTH:
        if DEBUG_MODE:
            print(f"Max depth reached for {url}, stopping recursion.")
        return "not found", "not found"

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
    except requests.RequestException:
        if DEBUG_MODE:
            print(f"Failed to fetch {url}")
        return "not found", "not found"

    soup = BeautifulSoup(response.text, "html.parser")
    for tag in soup.find_all("a", href=True):
        if is_valid_repo_url(tag["href"]):
            return fetch_license_from_ecosystems(tag["href"], depth + 1)

    return "not found", "not found"

def fetch_license_from_homepage_or_source(module_data):
    """Attempts to fetch the license using the module's homepage or source URL."""
    for key in ["Homepage", "Source URL"]:
        url = module_data.get(key, "N/A")
        if url and url != "N/A":
            license_info, repo_url = fetch_license_from_ecosystems(url)
            if license_info != "not found":
                return license_info, repo_url
    return "not found", "not found"

def process_modules_for_licenses(modules_file):
    """Processes module JSON file to retrieve license information."""
    with open(modules_file, "r") as f:
        modules = json.load(f)
    
    results = {}
    for module in modules:
        module_name = module["Module"]
        license_info, url = fetch_license_from_homepage_or_source(module)
        is_redistributable = False
        
        if isinstance(license_info, tuple):
            license_info = license_info[0]  # Extract the actual license ID
            if isinstance(license_info, tuple): # don't know why sometimes there are tuples of tuples
                license_info = license_info[0]  # Extract the actual license ID

        if isinstance(license_info, dict):
            license_info = license_info.get("id", "not found")  # Ensure it's a string

        if isinstance(license_info, list):
            license_info = ", ".join(license_info) if license_info else "not found"  # Convert list to string

        license_info_normalized = license_info.lower() if isinstance(license_info, str) else license_info

        if license_info_normalized in SPDX_LICENSES:
            spdx_details = SPDX_LICENSES[license_info_normalized]
            is_redistributable = spdx_details["isOsiApproved"] or spdx_details["isFsfLibre"]

        # Split the software name and version to display them properly in the YAML file
        software_name, version = module_name.split("/", 1)
        if "-" in version:
            version,toolchain = version.split("-",1)
        results[software_name] = {
            version: {
                "License": license_info,
                "Permission to redistribute": is_redistributable,
                "Retrieved from": url
            }
        }
    return results

def save_license_results(results, output_file="licenses_aux.yaml",licenses_original = os.sys.argv[2]):
    """Saves license information to a JSON file."""
    with open("temporal_print.yaml", "w") as f:
        yaml.dump(results, f, default_flow_style=False, sort_keys=True)  #Fast dump of what we have to print in the workflow

    full_data = {}
    with open(licenses_original, 'r') as f:
        full_data = yaml.safe_load(f)
    
    for software_name, versions_data in results.items():    #Look for new modules which are not in the new licenses dictionary
        if software_name not in full_data:                  #Add new modules in a data dictionary
            full_data[software_name] = {}

        for version, details in versions_data.items():      
            if version not in full_data[software_name]: 
                full_data[software_name][version] = details         #Add/replace the details of modules found in the new licenses data dictionary

    with open(output_file, "w") as f:
        yaml.dump(full_data, f, default_flow_style=False, sort_keys=True)  #Export data dictionary as licenses_aux.yaml file
    print(f"License information saved to {output_file}")    

def parse_arguments():
        parser = argparse.ArgumentParser(description='Script to parse licenses')
        parser.add_argument('input_file', help='Path to the input file')
        parser.add_argument('licenses_original', help='Path to the original licenses file (licenses.yml)')
        parser.add_argument('--debug', help='Prints scripts debugging', action='store_true', required=False)
        return parser.parse_args()

def main():
    modules_file = "modules_results.json"
    if not os.path.exists(modules_file):
        print(f"Error: {modules_file} not found.")
        return
    license_results = process_modules_for_licenses(modules_file)
    save_license_results(license_results)

if __name__ == "__main__":
    # Parse command-line arguments and enable global debug mode if requested
    args = parse_arguments()
    if args.debug:
        DEBUG_MODE = True
    main()
