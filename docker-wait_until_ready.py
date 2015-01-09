#!/usr/bin/env python
from __future__ import print_function

import requests, time, sys

def validateArguments():
	if ((len(sys.argv) > 4)):
		printUsage()
		sys.exit(1)
	if ((len(sys.argv) >= 2)):
		if (not sys.argv[1].isdigit()):
			print("ERROR: sleep_period ", sys.argv[1], "is not a valid period!")
			printUsage()
			sys.exit(1)
	if ((len(sys.argv) >= 3)):
		if (not sys.argv[2].isdigit()):
			print("ERROR: retry_period ", sys.argv[2], "is not a period!")
			printUsage()
			sys.exit(1)

def printUsage():
	print("\nUsage: python wait_until_ready.py [sleep_period] [retry_period]")
	print("\t Default sleep_period (between retries) is 5 seconds")
	print("\t Default retry_period (how long to continue to retry) is 300 seconds")

def getSleepPeriod():
	if ((len(sys.argv) >= 2)):
		if (sys.argv[1].isdigit()):
			return int(sys.argv[1])
	else:
		return DEFAULT_SLEEP_PERIOD

def getRetryPeriod():
	if ((len(sys.argv) >= 3)):
		if (sys.argv[2].isdigit()):
			return int(sys.argv[2])
	else:
		return DEFAULT_RETRY_PERIOD

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
		print('.', end=""); sys.stdout.flush()
		elapsedTime = time.time() - startTime

	print()
	return statusCode


# main
DEFAULT_SLEEP_PERIOD = 5
DEFAULT_RETRY_PERIOD = 300

DEFAULT_OPAC_URL = "http://localhost:8080"
DEFAULT_INTRA_URL = "http://localhost:8081"

validateArguments()

sleepPeriod = getSleepPeriod()
retryPeriod = getRetryPeriod()
opac_url = DEFAULT_OPAC_URL
intra_url = DEFAULT_INTRA_URL
exitCode = 0

print("INFO: opac_url:\t\t", opac_url)
print("INFO: intra_url:\t", intra_url)
print("INFO: sleepPeriod:\t", sleepPeriod)
print("INFO: retryPeriod:\t", retryPeriod, "\n")

if (kohaStatusCode(opac_url, sleepPeriod, retryPeriod) == 200):
	print("INFO: OPAC is running")
else:
	print("ERROR: OPAC is NOT running")
	exitCode = 1

if (exitCode > 0):
	sys.exit(exitCode)

if (kohaStatusCode(intra_url, sleepPeriod, retryPeriod) == 200):
	print("INFO: INTRA is running")
else:
	print("ERROR: INTRA is NOT running")
	exitCode = 1

sys.exit(exitCode)