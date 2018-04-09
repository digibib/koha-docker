#!/bin/sh
# /cronjobs/illrequests_cleanup.sh
#
# This cronjob completes illrequests when the item is not checked out, but
# illrequests still shows status O_ITEMSHIPPED or O_ITEMRETURNED.

echo "Forcing illrequests with status O_ITEMSHIPPED to DONE if item is not checked out"
QUERY="UPDATE illrequests i
         JOIN illrequestattributes ia USING(illrequest_id)
         JOIN items ON ia.value=items.barcode AND items.onloan IS NULL
          SET i.status='DONE',
              i.notesstaff=CONCAT('set to DONE by cronjob at ', now())
        WHERE i.status='O_ITEMSHIPPED' OR i.status='O_ITEMRETURNED'"
RES=`echo $QUERY | koha-mysql $(koha-list --enabled) -vv`
echo "$RES"

