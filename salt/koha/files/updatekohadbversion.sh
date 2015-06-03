#!/bin/bash
# small script to inject Koha db version to fresh install not done by webinstaller
KOHAVERSION=`perl -e 'require "/usr/share/koha/intranet/cgi-bin/kohaversion.pl" ; print kohaversion();' 2> /dev/null`


if [[ -n "$KOHAVERSION" ]] ; then
  KOHADBVERSION=`echo ${KOHAVERSION} | awk -F. '{ print $1"."$2$3$4 }'`
  KOHADBVERSIONOLD=`echo -n "SELECT value as '' FROM systempreferences WHERE variable = 'Version';" | sudo koha-mysql $INSTANCE | tail -1`
  MARCTAGSTRUCTURE=`echo -n "SELECT COUNT(*) FROM koha_$INSTANCE.marc_tag_structure where tagfield = 008;" | sudo koha-mysql $INSTANCE | tail -1`

  if [[ ! -z $KOHADBVERSIONOLD && ${KOHADBVERSIONOLD+x} ]] && \
     [[ $KOHADBVERSIONOLD = $KOHADBVERSION ]] && \
     [[ $MARCTAGSTRUCTURE = "1" ]] ; then
    # Up to date!

    COMMENT="Koha DB is up-to-date (version $KOHAVERSION) and MARC tag structure is nominally in place"

    echo  # Salt status
    echo "changed=no comment=\"${COMMENT}\" instance=$INSTANCE \
          newdbversion=\"$KOHADBVERSION\" olddbversion=$KOHADBVERSIONOLD"
  else
     RESULT=`/usr/bin/perl -e "require('/usr/local/bin/KohaWebInstallAutomation.pl') ; \
     KohaWebInstallAutomation->new( uri => \"${URL}\", user => \"${USER}\", pass => \"${PASS}\" );"`
     EXIT_CODE=$?
    echo  # Salt status
    if [[ $EXIT_CODE -ne 0 ]]; then
      echo "changed=no comment=\"${RESULT}\" instance=$INSTANCE \
          newdbversion=\"$KOHADBVERSION\" olddbversion=$KOHADBVERSIONOLD"
      exit $EXIT_CODE
    else
      echo "changed=yes comment=\"${RESULT}\" instance=$INSTANCE \
          newdbversion=\"$KOHADBVERSION\" olddbversion=$KOHADBVERSIONOLD"
    fi
  fi
else
  echo "changed=no comment=\"MISSING INSTANCENAME OR NO KOHAVERSION!\""
  exit 1
fi

