#!/bin/sh
# /cronjobs/delete_borrower_messages.sh --days
#
# This cronjob deletes messages sent to borrowers that are older than --days days

usage() {
  echo -e "\nUsage:\n$0 [-d|--days] \n"
  exit 1
}

delete_messages() {
    local DAYS=$1
    echo "deleting messages sent to borrowers older than $DAYS days ..."
    QUERY="DELETE from message_queue
            WHERE (TO_DAYS(now()) - TO_DAYS(time_queued)) >= $DAYS AND status in ('sent', 'failed')"
    RES=`echo $QUERY | koha-mysql $(koha-list --enabled) -vv`
    echo "$RES"
}

case "$1" in
    "")
    usage
    ;;
  --days|-d)
    shift
    delete_messages $1
    shift
    ;;
  --help|-h)
    usage
    ;;
esac
