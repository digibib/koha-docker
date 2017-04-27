BEGIN{
  FS=","
}
{
	print "\t<login encoding=\""$1"\" id=\""$2"\" password=\""$3"\" delimiter=\"|\" error-detect=\"enabled\" institution=\""$4"\" checked_in_ok=\"1\">"
	print "\t</login>"
}