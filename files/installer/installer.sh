#!/bin/bash -e
# This updates with local modifications incrementally based on local version
# If new db, do all mods
# NB: must be run BEFORE webinstaller, as it sets new DB version


trap "finish" INT TERM EXIT

KOHAVERSION=`perl -I/usr/share/koha/lib -e "use Koha; print Koha::version;" 2> /dev/null | awk -F. '{ print $1"."$2$3$4 }'`
CURRENTDBVERSION=`echo -n "SELECT value FROM systempreferences WHERE Variable='Version';" | koha-mysql $KOHA_INSTANCE | tail -n+2`
RESULT=''
EXIT_CODE=0

finish() {
    exit_code=$?
    echo -e "$RESULT"
    if [ -n $EXIT_CODE ];
    then
      exit $EXIT_CODE  # Exit with manually set EXIT_CODE from subshell/function/command
    else
      exit $exit_code  # Exit with exit code from 'exit 1' or similar
    fi
}

run_webinstaller() {
  if [[ -n "$KOHAVERSION" ]] ; then
    MARCTAGSTRUCTURE=`echo -n "SELECT COUNT(*) FROM koha_$KOHA_INSTANCE.marc_tag_structure where tagfield = 008;" | koha-mysql $KOHA_INSTANCE | tail -1`

    if [[ $CURRENTDBVERSION = $KOHAVERSION ]] && \
       [[ $MARCTAGSTRUCTURE > "0" ]] ; then
      # Koha DB already up to date!
      echo "Koha DB is already up-to-date (version $KOHAVERSION) and MARC tag structure is nominally in place"
    else
    RESULT=`/usr/bin/perl -e "require('/installer/KohaWebInstallAutomation.pl') ; \
        KohaWebInstallAutomation->new( uri => \"http://127.0.0.1:8081/\", user => \"${KOHA_ADMINUSER}\", pass => \"${KOHA_ADMINPASS}\" );"`
      EXIT_CODE=$?
    fi
  else
    RESULT="MISSING INSTANCENAME OR NO KOHAVERSION!"
    exit 1
  fi
}

apply_always() {
  if [ -n "$DEFAULT_LANGUAGE" ]; then
    echo "Installing the default language if not already installed ..."
    if [ -z `koha-translate --list | grep -Fx $DEFAULT_LANGUAGE` ] ; then
        RESULT=`koha-translate --install $DEFAULT_LANGUAGE`
        EXIT_CODE=$?
    fi

    echo -n "UPDATE systempreferences SET value = '$DEFAULT_LANGUAGE' WHERE variable = 'language';
        UPDATE systempreferences SET value = '$DEFAULT_LANGUAGE' WHERE variable = 'opaclanguages';" | \
        koha-mysql $KOHA_INSTANCE
        EXIT_CODE=$?
  fi

  if [ -n "$EMAIL_ENABLED" ]; then
    echo "Configuring email settings ..."
    # Koha uses perl5 Sendmail module defaulting to localhost, so need to override perl Sendmail config
    if [ -n "$SMTP_SERVER_HOST" ]; then
      sub="%mailcfg = (
        'smtp'    => [ '$SMTP_SERVER_HOST' ],
        'from'    => '', # default sender e-mail, used when no From header in mail
        'mime'    => 1, # use MIME encoding by default
        'retries' => 1, # number of retries on smtp connect failure
        'delay'   => 1, # delay in seconds between retries
        'tz'      => '', # only to override automatic detection
        'port'    => $SMTP_SERVER_PORT,
        'debug'   => 0,
      );"
      sendmail=/usr/share/perl5/Mail/Sendmail.pm
      awk -v sb="$sub" '/^%mailcfg/,/;/ { if ( $0 ~ /\);/ ) print sb; next } 1' $sendmail > tmp && \
        mv tmp $sendmail
      EXIT_CODE=$?
    fi
    # setup default debian exim4 to use smtp relay (used by sendmail and MIME::Lite)
    sed -i "s/dc_smarthost.*/dc_smarthost='mailrelay::2525'/" /etc/exim4/update-exim4.conf.conf
    sed -i "s/dc_eximconfig_configtype.*/dc_eximconfig_configtype='smarthost'/" /etc/exim4/update-exim4.conf.conf
    update-exim4.conf -v

    koha-email-enable $KOHA_INSTANCE
    EXIT_CODE=$?
  fi

  if [ -n "$ENABLE_MYSQL_TRIGGERS" ]; then
    echo "Setting up MYSQL triggers ..."
    # drop all triggers first
    echo -n "SELECT CONCAT('DROP TRIGGER ', TRIGGER_NAME, ';') FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = SCHEMA();" | \
      koha-mysql $KOHA_INSTANCE  -B --column-names=FALSE > /tmp/droptriggers.sql
    koha-mysql $KOHA_INSTANCE < /tmp/droptriggers.sql

    for trigger in /installer/triggers/*.sql
    do
        RESULT=`koha-mysql $KOHA_INSTANCE < $trigger`
        EXIT_CODE=$?
    done
  fi

  if [ -n "$ENABLE_MYSQL_SCHEMA" ]; then
    echo "Patching DBIx schema files ..."
    for schema in /installer/schema/*.patch
    do
      patch -d / -R -p1 -N --dry-run -i $schema > /dev/null # Dry run reverse to test if already applied
      rv=$?
      if [ $rv -eq 0 ]; then
          echo "-- Patch $schema already applied, ignoring..."
      else
        RESULT="`patch -d / -p1 -N < $schema` ------------> OK"
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
          RESULT="'Patch error: ${schema}'"
          exit $EXIT_CODE
        fi
      fi
      echo $RESULT
    done
  fi

  if [ -n "$ILLENABLE" ]; then
    echo "Configuring Interlibrary Loan Module Settings ..."
    echo -n "UPDATE systempreferences SET value = \"$ILLENABLE\" WHERE variable = 'ILLModule';" | koha-mysql $KOHA_INSTANCE
    echo -n "UPDATE systempreferences SET value = \"$ILLUSER\" WHERE variable = 'ILLISIL';" | koha-mysql $KOHA_INSTANCE
    EXIT_CODE=$?
  fi
}

apply_once() {
  local VERSION=16.0000000
  if expr "$CURRENTDBVERSION" '<=' "$VERSION" 1>/dev/null ; then
    echo "Configuring SMS settings ..."
    echo -n "UPDATE systempreferences SET value = \"$SMS_DRIVER\" WHERE variable = 'SMSSendDriver';" | koha-mysql $KOHA_INSTANCE
    echo -n "UPDATE systempreferences SET value = \"$SMS_USER\" WHERE variable = 'SMSSendUsername';" | koha-mysql $KOHA_INSTANCE
    echo -n "UPDATE systempreferences SET value = \"$SMS_PASS\" WHERE variable = 'SMSSendPassword';" | koha-mysql $KOHA_INSTANCE
    EXIT_CODE=$?
  fi

  VERSION=16.0600046
  if expr "$CURRENTDBVERSION" '<=' "$VERSION" 1>/dev/null ; then
    echo "Configuring National Library Card settings ..."
    if [ -n "$NLENABLE" ]; then
      echo -n "UPDATE systempreferences SET value = \"$NLENABLE\" WHERE variable = 'NorwegianPatronDBEnable';" | koha-mysql $KOHA_INSTANCE
      echo -n "UPDATE systempreferences SET value = \"$NLVENDORURL\" WHERE variable = 'NorwegianPatronDBEndpoint';" | koha-mysql $KOHA_INSTANCE
      echo -n "UPDATE systempreferences SET value = \"$NLBASEUSER\" WHERE variable = 'NorwegianPatronDBUsername';" | koha-mysql $KOHA_INSTANCE
      echo -n "UPDATE systempreferences SET value = \"$NLBASEPASS\" WHERE variable = 'NorwegianPatronDBPassword';" | koha-mysql $KOHA_INSTANCE
      EXIT_CODE=$?
    fi
  fi

  VERSION=16.0600047
  if expr "$CURRENTDBVERSION" '<=' "$VERSION" 1>/dev/null ; then
    echo "Setting up kemnersaker table ..."
    cat <<-EOF | koha-mysql $(koha-list --enabled)
        /*
         *   create table kemnersaker (unless exists)
         */
        CREATE TABLE IF NOT EXISTS kemnersaker (
        issue_id int(11) NOT NULL,
        borrowernumber int(11) NOT NULL,
        itemnumber int(11) NOT NULL,
        status varchar(10) COLLATE utf8_unicode_ci DEFAULT NULL,
        timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (issue_id),
        KEY kemner_issueidx (issue_id),
        KEY kemner_borroweridx (borrowernumber)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
EOF
  EXIT_CODE=$?
  fi

  VERSION=17.0501000
  if expr "$CURRENTDBVERSION" '<=' "$VERSION" 1>/dev/null ; then
    if [ -n "$ILLENABLE" ]; then
      echo "Setting up Interlibrary Loan ..."
      echo -n "INSERT INTO systempreferences (variable,value) VALUES ('ILLModule', \"$ILLENABLE\") ON DUPLICATE KEY UPDATE value = \"$ILLENABLE\";" | koha-mysql $KOHA_INSTANCE
      echo -n "INSERT INTO systempreferences (variable,value,type) VALUES ('ILLISIL', \"$ILLUSER\", 'free') ON DUPLICATE KEY UPDATE value = \"$ILLUSER\";" | koha-mysql $KOHA_INSTANCE
      echo -n "INSERT IGNORE INTO branches (branchcode,branchname) VALUES ('ILL', \"$ILLNAME\");" | koha-mysql $KOHA_INSTANCE
      echo -n "INSERT IGNORE INTO categories (categorycode,description,enrolmentperioddate,overduenoticerequired,category_type) VALUES ('IL', \"$ILLNAME\", '2999-12-31', 1, 'I');" | koha-mysql $KOHA_INSTANCE
      echo -n "INSERT IGNORE INTO borrower_attribute_types (code,description,unique_id,class) VALUES ('nncip_uri', 'NNCIP endpoint', 1, 'nncip_uri');" | koha-mysql $KOHA_INSTANCE
      echo "Adding Fast Add framework (FA) - needed for Interlibrary loans ..."
      if [[ "$KOHA_HOME" == /usr/share* ]] ; then
        koha-mysql $KOHA_INSTANCE < /usr/share/koha/intranet/cgi-bin/installer/data/mysql/en/marcflavour/marc21/optional/marc21_sample_fastadd_framework.sql
      else
        koha-mysql $KOHA_INSTANCE < ${KOHA_HOME}installer/data/mysql/en/marcflavour/marc21/optional/marc21_sample_fastadd_framework.sql
      fi
      EXIT_CODE=$?
    fi
  fi
}

run_webinstaller
apply_always
apply_once