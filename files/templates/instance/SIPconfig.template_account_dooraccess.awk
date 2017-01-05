BEGIN{
  FS=","
}
{
	print "\t<login encoding=\""$1"\" id=\""$2"\" password=\""$3"\" delimiter=\"|\" error-detect=\"enabled\" institution=\""$4"\" validate_patron_attribute=\"dooraccess\" />"
}