BEGIN{
  FS=","
}
{
	print "\t<login encoding=\"utf8\" id=\""$1"\" password=\""$2"\" delimiter=\"|\" error-detect=\"enabled\" institution=\""$3"\" validate_patron_attribute=\"dooraccess\" />"
}