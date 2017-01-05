BEGIN{
  FS=","
}
{
	print "\t<institution id=\""$1"\" implementation=\"ILS\" parms=\"\">"
	print "\t\t<policy checkin=\"true\" renewal=\"true\" checkout=\"true\""
	print "\t\t\tstatus_update=\"false\" offline=\"false\" timeout=\"1800\" retries=\"5\" />"
	print "\t</institution>"
}
