import requests, time, sys
import docker, json

RETRY_PERIOD = 300
SLEEP_PERIOD = 5
opac_url = "http://localhost:8080"
intra_url = "http://localhost:8081"


 
def list_containers():
    c = docker.Client(base_url="unix://var/run/docker.sock")
    return c.containers(quiet=False, all=False, trunc=True, latest=False, since=None,
             before=None, limit=-1)

def isKohaDockerRunning():
	b = False
	for x in list_containers():
		for y in x["Names"]:
			if (y == "/koha_docker"):
				b = True
	return b

def getMaxRetryPeriod():
	s = 0
	if ((len(sys.argv) > 1) and (sys.argv[1].isdigit())):
		s = int(sys.argv[1])
	else:
		s = RETRY_PERIOD

	return s

def doRequest(url):
	statusCode = 0
	try: 
		# Note: do NOT follow redirect:
		statusCode = requests.get(url, allow_redirects=False).status_code
	except Exception as e:
		pass
	return statusCode

def kohaStatusCode(url, s):
	startTime = time.time()
	statusCode = doRequest(url)
	elapsedTime = time.time() - startTime

	while ((statusCode != 200) and (elapsedTime < s)):
		time.sleep(SLEEP_PERIOD)
		statusCode = doRequest(url)
		elapsedTime = time.time() - startTime

	if (statusCode != 200):
		return 0
	else:
		return statusCode


# main
s = getMaxRetryPeriod()

if (not isKohaDockerRunning()):
	print "ERROR: docker-container koha_docker is NOT running"
	sys.exit(1)
else:
	print "INFO: docker-container koha_docker is running"

if (kohaStatusCode(opac_url, s) == 0):
	print "ERROR: OPAC is NOT running"
	sys.exit(1)
else:
	print "INFO: OPAC is running"

if (kohaStatusCode(intra_url, s) == 0):
	print "ERROR: INTRA is NOT running"
	sys.exit(1)
else:
	print "INFO: INTRA is running"
