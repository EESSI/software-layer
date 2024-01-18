# this will ingest GitHub REST API output to a list
# recovering the information

# command that do the magic:
#curl -L  -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer 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"   -H "X-GitHub-Api-Version: 2022-11-28"   https://api.github.com/repos/SINGROUP/SOAPLite/license | jq  '.license|{spdx_id}'

# python traduction:
import requests
import argparse
import json

parser=argparse.ArgumentParser(description='Script to ingest licences')

parser.add_argument('--source', help='Project available in GitHub,pypi,cran')
parser.add_argument('project', help='Project. For GitHub you should specify owner/repo')
parser.add_argument('--spdx')
args=parser.parse_args()

def gitHUBLicenses(repo):
	"""
	Function that gets spdx_id from github using his API
	"""
	
	url="https://api.github.com/repos/"+repo+"/license"
	headers = {
		"Accept": "application/vnd.github+json",
		"Authorization" : "Bearer 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",
		"X-GitHub-Api-Version": "2022-11-28",
	}
	
	test=requests.get(url, headers=headers)
	if test==200:
		return(test.json()['license']['spdx_id'])
	else:
		return('no available')

def pypiLicenses(project):
	"""
	Function that retrives licence from PiPy
	"""
	url = "https://pypi.org/pypi/"
	r = requests.get(url + project  + "/json").json()
	return(r['info']['license'])

def CRANLicenses(project):
    """
	Function that retrieves licence from CRAN
	"""
    url = "http://crandb.r-pkg.org/"
    r = requests.get(url + project).json()
    return(r['License'])
	
#    if r.status_code != 200:
#        return "not found"
#    else:
#        return r.json()['Licence']    

def updateJson(licenseInfo):
#	"""
#	Function that updates json file
#	"""
	with open('dummy.json', 'w') as dummy:
		json.dump(licenseInfo,dummy)
def licenseInfo(project):
	"""
	Function that create the project dict
	"""
	if args.pypi: 
		lic=pypiLicenses(project)
		source="pypi"
		info=dict(license=lic, source=source)
		test={project:info}
#	if args.github:
#		lic=gitHUBLicenses(args.project)
#	if args.cran:
#		lic=CRANLicenses(args.project)
	# fill the dictionary with
	#	{
	# "Software": {
	#         "license": "license", 
	#         "source": "manual, pypi, cran, repology, libraries.io,.."
	#         "spdx": "spdx_id",
	#}
	#
	return test

def main():
	updateJson(licenseInfo(args.project))
#	repo="SINGROUP/SOAPLite"
#	print(gitHUBLicenses("SINGROUP/SOAPLite"))
#	pypiLicenses("easybuild")
#	CRANLicenses('mirai')


main()

