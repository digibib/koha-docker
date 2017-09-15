#!/bin/sh
# /cronjobs/anonymize_last_borrower.sh --days
#
# This cronjob sets the borrower in items_last_borrower to
# anonymous patron (327742) when checkin is older than --days

usage() {
  echo -e "\nUsage:\n$0 [-d|--days] \n"
  exit 1
}

anonymize() {
    local DAYS=$1
    echo "anonymizing last borrower when whckin is older than $DAYS days old ..."
    QUERY="UPDATE items_last_borrower
              SET borrowernumber=327742
           WHERE (TO_DAYS(now()) - TO_DAYS(created_on)) >= $DAYS;"
    RES=`echo $QUERY | koha-mysql $(koha-list --enabled) -vv`
    echo "$RES"
}

case "$1" in
    "")
    usage
    ;;
  --days|-d)
    shift
    anonymize $1
    shift
    ;;
  --help|-h)
    usage
    ;;
esac
