#!/bin/bash
# small script to inject Koha db version to fresh install not done by webinstaller
KOHAVERSION=`perl -e 'require "/usr/share/koha/intranet/cgi-bin/kohaversion.pl" ; print kohaversion();' 2> /dev/null`


if [[ -n "$KOHAVERSION" ]] ; then
  KOHADBVERSION=`echo ${KOHAVERSION} | awk -F. '{ print $1"."$2$3$4 }'`
  KOHADBVERSIONOLD=`echo -n "SELECT value as '' FROM systempreferences WHERE variable = 'Version';" | sudo koha-mysql $KOHA_INSTANCE | tail -1`
  MARCTAGSTRUCTURE=`echo -n "SELECT COUNT(*) FROM koha_$KOHA_INSTANCE.marc_tag_structure where tagfield = 008;" | sudo koha-mysql $KOHA_INSTANCE | tail -1`

  if [[ ! -z $KOHADBVERSIONOLD && ${KOHADBVERSIONOLD+x} ]] && \
     [[ $KOHADBVERSIONOLD = $KOHADBVERSION ]] && \
     [[ $MARCTAGSTRUCTURE = "1" ]] ; then
    # Up to date!
    CHANGED=no
    RESULT="Koha DB is up-to-date (version $KOHAVERSION) and MARC tag structure is nominally in place"
    EXIT_CODE=0
  else
    RESULT=`/usr/bin/perl -e "require('/installer/KohaWebInstallAutomation.pl') ; \
    KohaWebInstallAutomation->new( uri => \"http://127.0.0.1:8081/\", user => \"${KOHA_ADMINUSER}\", pass => \"${KOHA_ADMINPASS}\" );"`
    echo $RESULT
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
      CHANGED=no
    else
      CHANGED=yes
    fi
  fi
else
  RESULT="MISSING INSTANCENAME OR NO KOHAVERSION!"
  EXIT_CODE=1
fi
echo # Salt status
echo "changed=$CHANGED comment=\"${RESULT}\" instance=$KOHA_INSTANCE \
          newdbversion=\"${KOHADBVERSION}\" olddbversion=\"${KOHADBVERSIONOLD}\""
exit $EXIT_CODE

