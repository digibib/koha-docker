#!/bin/bash
# /root/kemnersaker.sh
report="REPORT FROM TODAYS kemnersaker\n"

add_new_items() {
  # add new lines to kemnersaker where issue is between 35 and 90 days overdue and it hasn't been registered before
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    INSERT INTO kemnersaker (issue_id,borrowernumber,itemnumber,status,timestamp)
    ( SELECT oi.issue_id,
             oi.borrowernumber,
             oi.itemnumber,
             'new',
             TIMESTAMP(NOW())
      FROM old_issues oi
      JOIN items it ON (it.itemnumber=oi.itemnumber)
      JOIN borrowers b ON (b.borrowernumber=oi.borrowernumber)
 LEFT JOIN kemnersaker k ON (oi.issue_id=k.issue_id)
     WHERE (TO_DAYS(now()) - TO_DAYS(oi.date_due)) BETWEEN 35 AND 90
       AND k.issue_id IS NULL
       AND it.itemlost = '12'
       AND b.categorycode IN ('V',
                               'B',
                               'I')
       AND NOT (b.categorycode = 'B'
           AND b.branchcode = 'fsme'));

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
    INSERT INTO borrower_debarments (borrowernumber, type, comment, manager_id)
      (SELECT k.borrowernumber,
              'MANUAL',
              'Sendt til kemner',
              49393
       FROM kemnersaker k
       JOIN borrowers b USING(borrowernumber)
       WHERE NOT EXISTS
           ( SELECT *
            FROM borrower_debarments
            WHERE borrowernumber=k.borrowernumber
              AND comment='Sendt til kemner' )
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
