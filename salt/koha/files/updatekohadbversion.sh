#!/bin/bash
# small script to inject Koha db version to fresh install not done by webinstaller
KOHAVERSION=`perl -e 'require "/usr/share/koha/intranet/cgi-bin/kohaversion.pl" ; print kohaversion();' 2> /dev/null`


if [[ -n "$KOHAVERSION" ]] ; then
  KOHADBVERSION=`echo ${KOHAVERSION} | awk -F. '{ print $1"."$2$3$4 }'`
  KOHADBVERSIONOLD=`echo -n "SELECT value as '' FROM systempreferences WHERE variable = 'Version';" | sudo koha-mysql $INSTANCE | tail -1`
  MARCTAGSTRUCTURE=`echo -n "SELECT COUNT(*) FROM koha_name.marc_tag_structure where tagfield = 008;" | sudo koha-mysql $INSTANCE | tail -1`

  if [[ ! -z $KOHADBVERSIONOLD && ${KOHADBVERSIONOLD+x} ]] && \
     [[ $KOHADBVERSIONOLD = $KOHADBVERSION ]] && \
     [[ $MARCTAGSTRUCTURE = "1" ]] ; then
    # Up to date!
    CMD=""
    CHANGED=no
    COMMENT="Koha DB is up-to-date (version $KOHAVERSION) and MARC tag structure is nominally in place"

    # return Salt State line
    echo  # an empty line here so the next line will be the last.
    echo "{\"changed\":\"$CHANGED\",\
          \"comment\":\"$COMMENT\",\
          \"cmd\":\"$CMD\",\
          \"instance\":\"$INSTANCE\",\
          \"newdbversion\":\"$KOHADBVERSION\",\
          \"olddbversion\":\"$KOHADBVERSIONOLD\"\
          }"
  else
     ruby -r "/usr/local/bin/KohaWebInstallAutomation.rb" -e "KohaWebInstallAutomation.new \"${URL}\",\"${USER}\",\"${PASS}\""
  fi
else
  echo "{\"ERROR\":\"MISSING INSTANCENAME OR NO KOHAVERSION!\"}"
  exit 1
fi

