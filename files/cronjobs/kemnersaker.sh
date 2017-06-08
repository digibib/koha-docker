#!/bin/bash
# /root/kemnersaker.sh
report="REPORT FROM TODAYS kemnersaker\n"

add_new_items() {
  # add new lines to kemnersaker where issue is more than 35 days overdue
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    INSERT INTO kemnersaker (issue_id,borrowernumber,itemnumber,status,TIMESTAMP)
    SELECT i.issue_id,
           i.borrowernumber,
           i.itemnumber,
           'new',
           TIMESTAMP(NOW())
    FROM issues i
    JOIN items it ON (it.itemnumber=i.itemnumber)
    JOIN borrowers b ON (b.borrowernumber=i.borrowernumber)
    WHERE (TO_DAYS(now()) - TO_DAYS(i.date_due)) = '36'
      AND it.itemlost = '12'
      AND b.categorycode IN ('V',
                             'B',
                             'I')
      AND NOT (b.categorycode = 'B'
               AND b.branchcode = 'fsme');

    SELECT ROW_COUNT();
EOF`"
    report+="new cases:\t${RES}\n"
}

update_returned_items() {
  # sets status to 'returned' for yesterdays returns, or 'lost_paid' if item is marked with itemlost=8
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE kemnersaker k
    JOIN old_issues oi ON (oi.itemnumber=k.itemnumber)
    JOIN items i ON (i.itemnumber=k.itemnumber)
    SET k.status=
      ( SELECT CASE i.itemlost
                   WHEN '8' THEN 'lost_paid'
                   ELSE 'returned'
               END),
        k.timestamp=TIMESTAMP(NOW())
    WHERE DATE_SUB(DATE(NOW()), INTERVAL 1 DAY) = DATE(oi.returndate)
      AND k.status IN ('new',
                       'sent');

    SELECT ROW_COUNT();
EOF`"
    report+="new returns:\t${RES}\n"
}

block_patrons() {
  local RES=`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    INSERT INTO borrower_debarments (borrowernumber, TYPE, COMMENT, manager_id)
      (SELECT k.borrowernumber,
              'MANUAL',
              'Sendt til kemner',
              49393
       FROM kemnersaker k
       WHERE NOT EXISTS
           ( SELECT *
            FROM borrower_debarments
            WHERE borrowernumber=k.borrowernumber
              AND COMMENT='Sendt til kemner' )
         AND k.status IN ('new',
                          'sent'));

    UPDATE borrowers b
    JOIN kemnersaker k ON (k.borrowernumber=b.borrowernumber)
    SET debarred='2999-01-01'
    WHERE k.status IN ('new',
                       'sent');

    SELECT ROW_COUNT();
EOF`
    report+="blocked patrons:\t${RES}\n"
}

finish_jobs() {
    echo "TODO: end cases handled manually until we get automated reports"
}

add_new_items
update_returned_items
block_patrons
echo -e ${report}
