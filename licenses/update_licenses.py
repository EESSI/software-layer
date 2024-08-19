import requests
import argparse
import json
import os
from datetime import datetime

parser = argparse.ArgumentParser(description='Script to ingest licenses')
parser.add_argument('--source', help='Source (GitHub, PyPI, CRAN, Repology) or user')
parser.add_argument('projects', nargs='+', help='List of project names')
parser.add_argument('--manual', help='Manually provided license', required=False)
parser.add_argument('--spdx', help='SPDX identifier for the license', required=False)
args = parser.parse_args()

# Retrieve license from various sources
def github(source):
    repo = source.removeprefix('github:')
    url = (
        "https://api.github.com/repos/{repo}/license".format(repo=repo)
    )
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer {}".format(os.getenv('GITHUB_TOKEN')),
        "X-GitHub-Api-Version": "2022-11-28",
    }
    r = requests.get(url, headers=headers)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    return data['license']['spdx_id'], 'GitHub', data['license']['url']

def pypi(project):
    url = "https://pypi.org/pypi/{project}/json".format(project=project)
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    return data['info']['license'], 'PyPI', data['info'].get('project_url')

def cran(project):
    url = "http://crandb.r-pkg.org/{project}".format(project=project)
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    return data['License'], 'CRAN', None

def repology(project):
    url = "https://repology.org/api/v1/project/{project}".format(
        project=project
    )
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    return data.get('license', 'not found'), 'Repology', None

def ecosysteDotms_pypi(project):
    url = "https://packages.ecosyste.ms/api/v1/registries/pypi.org/packages/{project}".format(
        project=project
    )
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    return data.get('license', 'not found'), 'Ecosyste.ms (PyPI)', None

def ecosysteDotms_github(source):
    repo = source.removeprefix('github:')
    url = "https://repos.ecosyste.ms/api/v1/hosts/GitHub/repositories/{repo}".format(
        repo=repo
    )
    r = requests.get(url)
    if r.status_code != 200:
        return "not found", None, None
    data = r.json()
    return data.get('license', 'not found'), 'Ecosyste.ms (GitHub)', None

# Main license retrieval function
def license_info(project):
    if args.source == 'pypi':
        lic, source, url = ecosysteDotms_pypi(project)
    elif "github" in args.source:
        lic, source, url = ecosysteDotms_github(args.source)
    elif args.manual:
        lic = args.manual
        source = args.source
        url = None
    else:
        lic, source, url = "not found", None, None

    spdx_id = args.spdx if args.spdx else (lic if lic and lic != "not found" else None)

    info = {
        "license": lic,
        "source": source,
        "spdx_id": spdx_id,
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
        print('Added new license for project {project}'.format(project=project))

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
    if os.path.exists('licenses.json'):
        with open('licenses.json', 'r') as lic_dict:
            licenses = json.loads(lic_dict.read())
    else:
        licenses = {}

    for project in args.projects:
        info = license_info(project)
        update_json(licenses, project, info)

    patch = generate_patch(licenses)
    save_patch(patch)

    with open('licenses.json', 'w') as lic_file:
        lic_file.write(patch)

    print("Patch output:\n{patch}".format(patch=patch))

if __name__ == "__main__":
    main()

