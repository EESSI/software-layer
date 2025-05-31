import requests
import argparse
import json
import os
import re
from datetime import datetime

url_repo = "https://repos.ecosyste.ms/api/v1/hosts"    
url_reg = "https://packages.ecosyste.ms/api/v1/registries"

def ecosystems_list(url): 
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    listing = []
    for reg in data: 
        listing.append(reg["name"])
    return(listing)

def validate_repo_format(value):
    # Validates the input format <hostname>:<user>/<repository> and ensures the hostname is allowed.
    pattern = r'^([^:]+):(?:(\w+)/)?([^/]+)/(.+)$'
    match = re.match(pattern, value)
    
    if not match:
        raise argparse.ArgumentTypeError(
            f"Invalid format. Use <hostname>:<user>/<repository> or or <hostname>:<group>/<user>/<repo>.")
    
    hostname, group, user, repo = match.groups()
    
    if hostname not in ecosystems_list(url_repo):
        raise argparse.ArgumentTypeError(
            f"Invalid hostname '{hostname}'. Check '--repo help'"
        )
    
    return value  # Return the validated string

def parse_arguments(): 
    
    # Positional arguments
    parser = argparse.ArgumentParser(description='Script to ingest licenses')
    parser.add_argument('project', nargs='+', help='List of project name')
    parser.add_argument(
        '--manual', help='Manually provided license', required=False)
    parser.add_argument(
        '--spdx', help='SPDX identifier for the license', required=False)
    
    # Now the complicated ones
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--registry', help='Origin registry. Use "--registry help" to see all available options', metavar='REGISTRY', choices=ecosystems_list(url_reg))
    group.add_argument('--repo', help='Origin repository. Format: <host>:<user>/<repo>. All available hosts shown with "--repo help"', metavar='REPOSITORY', type=validate_repo_format)

    args = parser.parse_args()
    return args

# Retrieve license from  ecosyste.ms package API
def ecosystems_packages(registry, package):
    print("available registries: ")
    ecosystems_registries()
    url = "https://packages.ecosyste.ms/api/v1/registries/{registry}/packages/{package}".format(
        registry=registry, package=package
    )
    print(url)
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    print(data.get('licenses'))
    return data.get('normalized_licenses', 'not found'), registry 

# Retrieve license from ecosyste.ms repo API 
def ecosystems_repo(repository, source):
#    hostname, user, repo = re.match(r'^([^:]+):([^/]+)/(.+)$', repository).groups()
    hostname, group, user, repo = re.match(r'^([^:]+):(?:(\w+)/)?([^/]+)/(.+)$', repository).groups()
    
    if group: 
        url = "https://repos.ecosyste.ms/api/v1/hosts/{hostname}/repositories/{group}%2F{user}%2F{repo}".format(
        hostname=hostname, group=group, user=user, repo=repo)
    else: 
        url = "https://repos.ecosyste.ms/api/v1/hosts/{hostname}/repositories/{user}%2F{repo}".format(
        hostname=hostname, user=user, repo=repo)
    print(url)
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    return data.get('license', 'not found')

# Main license retrieval function
def go_fetch(args):
    if args.registry:
        lic, source = ecosystems_packages(args.registry, args.project)
    elif args.repo:
        lic = ecosystems_repo(args.repo, args.project)
    else:
        lic, source, url = "not found", None, None
        spdx_id = args.spdx if args.spdx else (
        lic if lic and lic != "not found" else None)

    info = {
        "license": lic,
#        "source": source,
        "retrieved_at": datetime.now().isoformat(),
    }
    return info


def update_json(licenses, project, info):
    if project in licenses:
        if 'history' not in licenses[project]:
            licenses[project]['history'] = []
        licenses[project]['history'].append(info)
        licenses[project]['current'] = info
        print('Updated license for project {project}'.format(project=project))
    else:
        licenses[project] = {
            "current": info,
            "history": [info],
        }
        print('Added new license for project {project}'.format(
            project=project))

    lic_json = json.dumps(licenses, indent=4)
    with open('licenses.json', 'w') as lic_file:
        lic_file.write(lic_json)

    return licenses

# Create patch output


def generate_patch(licenses):
    patch = json.dumps(licenses, indent=4)
    return patch

# Function to save patch to a file


def save_patch(patch_content, filename="license_update.patch"):
    with open(filename, 'w') as patch_file:
        patch_file.write(patch_content)
    print("Patch saved to {filename}".format(filename=filename))


def main():
    args = parse_arguments()

    if os.path.exists('licenses.json'):
        with open('licenses.json', 'r') as lic_dict:
            licenses = json.loads(lic_dict.read())
    else:
        licenses = {}

    for project in args.project:
        # add if not manual, this just for fetching the license!
        if not args.manual:
            # we fetchin'
            info = go_fetch(args)
            update_json(licenses, project, info)
        else: 
            # we inserting it manually
            info = {
                "license": args.spdx,
                "retrieved_at": datetime.now().isoformat(),
            }
	

    patch = generate_patch(licenses)
    save_patch(patch)

    with open('licenses.json', 'w') as lic_file:
        lic_file.write(patch)

    print("Patch output:\n{patch}".format(patch=patch))


if __name__ == "__main__":
    main()
