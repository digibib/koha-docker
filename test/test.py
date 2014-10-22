import requests, time, sys, docker

def validateArguments():
	if ((len(sys.argv) < 2)):
		printUsage()
		sys.exit(1)
	if ((len(sys.argv) >= 2)):
		if (sys.argv[1].isdigit()):
			print "ERROR: ContainerName ", sys.argv[1], "is not a valid name!"
			printUsage()
			sys.exit(1)
	if ((len(sys.argv) >= 3)):
		if (not sys.argv[2].isdigit()):
			print "ERROR: sleep_period ", sys.argv[2], "is not a valid period!"
			printUsage()
			sys.exit(1)
	if ((len(sys.argv) >= 4)):
		if (not sys.argv[3].isdigit()):
			print "ERROR: retry_period ", sys.argv[3], "is not a period!"
			printUsage()
			sys.exit(1)

def printUsage():
	print "\nUsage: python test.py <container_name> [sleep_period] [retry_period]"
	print "\t Default sleep_period is 5 seconds"
	print "\t Default retry_period is 300 seconds"

def getContainerName():
	return sys.argv[1]

def getSleepPeriod():
	if ((len(sys.argv) >= 3)):
		if (sys.argv[2].isdigit()):
			return int(sys.argv[2])
	else:
		return DEFAULT_SLEEP_PERIOD

def getRetryPeriod():
	if ((len(sys.argv) >= 4)):
		if (sys.argv[3].isdigit()):
			return int(sys.argv[3])
	else:
		return DEFAULT_RETRY_PERIOD

def list_containers():
    c = docker.Client(base_url="unix://var/run/docker.sock")
    return c.containers(quiet=False, all=False, trunc=True, latest=False, since=None,
             before=None, limit=-1)

def isKohaDockerRunning(name):
	b = False
	for x in list_containers():
		for y in x["Names"]:
			if (y[1:] == name): #the first character is a "/". We ignore it.
				b = True
	return b

def doRequest(url):
	statusCode = 0
	try: 
		# Note: do NOT follow redirect:
		statusCode = requests.get(url, allow_redirects=False).status_code
	except Exception as e:
		pass
	return statusCode

def kohaStatusCode(url, sleepPeriod, retryPeriod):
	startTime = time.time()
	statusCode = doRequest(url)
	elapsedTime = time.time() - startTime

	while ((statusCode != 200) and (elapsedTime < retryPeriod)):
		time.sleep(sleepPeriod)
		statusCode = doRequest(url)
		elapsedTime = time.time() - startTime

	return statusCode


# main
DEFAULT_SLEEP_PERIOD = 5
DEFAULT_RETRY_PERIOD = 300

DEFAULT_OPAC_URL = "http://localhost:8080"
DEFAULT_INTRA_URL = "http://localhost:8081"

validateArguments()

containerName = getContainerName()
sleepPeriod = getSleepPeriod()
retryPeriod = getRetryPeriod()
opac_url = DEFAULT_OPAC_URL
intra_url = DEFAULT_INTRA_URL
exitCode = 0

print "INFO: containerName:\t", containerName
print "INFO: opac_url:\t\t", opac_url
print "INFO: intra_url:\t", intra_url
print "INFO: sleepPeriod:\t", sleepPeriod
print "INFO: retryPeriod:\t", retryPeriod, "\n"

if (isKohaDockerRunning(containerName)):
	print "INFO: docker-container", containerName, "is running"
else:
	print "ERROR: docker-container", containerName, "is NOT running"
	sys.exit(1)

if (kohaStatusCode(opac_url, sleepPeriod, retryPeriod) == 200):
	print "INFO: OPAC is running"
else:
	print "ERROR: OPAC is NOT running"
	exitCode = 1

if (kohaStatusCode(intra_url, sleepPeriod, retryPeriod) == 200):
	print "INFO: INTRA is running"
else:
	print "ERROR: INTRA is NOT running"
	exitCode = 1

sys.exit(exitCode)