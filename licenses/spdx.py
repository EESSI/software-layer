import json
import logging
import sys
import urllib.request

SPDX_LICENSE_LIST_URL = 'https://raw.githubusercontent.com/spdx/license-list-data/main/json/licenses.json'

LICENSE_URL = 'license_url'
SPDX = 'spdx'

spdx_license_list = None

# Configure the logging module
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")


def get_spdx_license_list():
    """
    Download JSON file with current list of SPDX licenses, parse it, and return it as a Python dictionary.
    """
    global spdx_license_list

    if spdx_license_list is None:
        with urllib.request.urlopen(SPDX_LICENSE_LIST_URL) as fp:
            spdx_license_list = json.load(fp)
        version, release_date = spdx_license_list['licenseListVersion'], spdx_license_list['releaseDate']
        logging.info(f"Downloaded version {version} of SPDX license list (release date: {release_date})")
        licenses = spdx_license_list['licenses']
        logging.info(f"Found info on {len(licenses)} licenses!")

    return spdx_license_list


def license_info(spdx_id):
    """Find license with specified SPDX identifier."""
 
    spdx_license_list = get_spdx_license_list()

    licenses = spdx_license_list['licenses']
    for lic in licenses:
        if lic['licenseId'] == spdx_id:
            return lic

    # if no match is found, return None as result
    return None


def read_licenses(path):
    """
    Read software project to license mapping from specified path
    """
    with open(path) as fp:
        licenses = json.loads(fp.read())

    return licenses


def check_licenses(licenses):
    """
    Check mapping of software licenses: make sure SPDX identifiers are valid.
    """
    faulty_licenses = {}

    for software_name in licenses:
        spdx_lic_id = licenses[software_name][SPDX]
        lic_info = license_info(spdx_lic_id)
        if lic_info:
            lic_url = licenses[software_name][LICENSE_URL]
            logging.info(f"License for software '{software_name}': {lic_info['name']} (see {lic_url})")
        else:
            logging.warning(f"Found faulty SPDX license ID for {software_name}: {spdx_lic_id}")
            faulty_licenses[software_name] = spdx_lic_id

    if faulty_licenses:
        logging.warning(f"Found {len(faulty_licenses)} faulty SPDIX license IDs (out of {len(licenses)})!")
        result = False
    else:
        logging.info(f"License check passed for {len(licenses)} licenses!")
        result = True

    return result


def main(args):
    if len(args) == 1:
        licenses_path = args[0]
    else:
        logging.error("Usage: python spdx.py <path to licenses.json>")
        sys.exit(1)

    licenses = read_licenses(licenses_path)
    if check_licenses(licenses):
        logging.info("All license checks PASSED!")
    else:
        logging.error("One or more licence checks failed!")
        sys.exit(2)


if __name__ == '__main__':
    main(sys.argv[1:])
