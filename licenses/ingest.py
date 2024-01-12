# this will ingest GitHub REST API output to a list
# recovering the information

# command that do the magic:
#curl -L  -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer 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"   -H "X-GitHub-Api-Version: 2022-11-28"   https://api.github.com/repos/SINGROUP/SOAPLite/license | jq  '.license|{spdx_id}'

# python traduction:
import requests

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
    url = "http://crandb.r-pkg.org/"
    r = requests.get(url + project).json()
    print(r['License'])
	
#    if r.status_code != 200:
#        return "not found"
#    else:
#        return r.json()['Licence']    

def main():
#	repo="SINGROUP/SOAPLite"
#	gitHUBLicenses("SINGROUP/SOAPLite")
#	pypiLicenses("easybuild")
#	CRANLicenses('mirai')
Other packages


main()

