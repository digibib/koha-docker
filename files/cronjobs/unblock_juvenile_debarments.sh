#!/bin/bash
# /root/unblock_juvenile_debarments.sh
report="REPORT FROM CRONJOB unblock_juvenile_debarments.sh\n"

unblock_juveniles_with_kemnersak() {
  # Remove 'debarred' on patrons in category 'B'
  # with no more issues but with pending kemnersak
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE borrowers b
    JOIN
      ( SELECT bd.*,
               COUNT(iss.issue_id) AS issuecount
        FROM borrower_debarments bd
        JOIN borrowers b ON (b.borrowernumber=bd.borrowernumber)
        JOIN kemnersaker k ON (k.borrowernumber=bd.borrowernumber)
        JOIN issues iss USING (issue_id)
        WHERE b.categorycode IN ('B','SKO','BHG')
          AND bd.type = 'MANUAL'
        GROUP BY b.cardnumber HAVING issuecount = 0
        AND bd.comment IN ('Sendt til kemner',
                           'Regning') ) niceperson USING (borrowernumber)
    SET b.debarred = NULL, b.debarredcomment = NULL;

    DELETE bd
    FROM borrower_debarments bd
    JOIN
      ( SELECT bd.*,
               COUNT(iss.issue_id) AS issuecount
        FROM borrower_debarments bd
        JOIN borrowers b ON (b.borrowernumber=bd.borrowernumber)
        JOIN kemnersaker k ON (k.borrowernumber=bd.borrowernumber)
        JOIN issues iss USING (issue_id)
        WHERE b.categorycode IN ('B','SKO','BHG')
          AND bd.type = 'MANUAL'
        GROUP BY b.cardnumber HAVING issuecount = 0
        AND bd.comment IN ('Sendt til kemner',
                           'Regning') ) niceperson USING (borrower_debarment_id);

    SELECT ROW_COUNT();
EOF`"
  report+="Unblocking juveniles with kemnersak:\t${RES}\n"
}

unblock_juveniles_with_overdues() {
  # 1) Remove borrower_debarments on patrons in category 'B'
  # with no more issues OR no issues overdue by more than 10 days AND no kemnersak
  # but which are blocked due to restriction set by overdue process
  # 2) remove 'debarred' and 'debarredcomment' on 'B' patrons with no more debarments
  # that still have OVERDUES debarment
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    DELETE bd
    FROM borrower_debarments bd
    JOIN
      ( SELECT b.cardnumber,bd.*, COUNT(iss.issue_id) AS issuecount
        FROM borrower_debarments bd
        JOIN borrowers b USING (borrowernumber)
        LEFT JOIN issues iss ON (
          iss.borrowernumber=b.borrowernumber
              AND DATE(NOW()) > DATE_ADD(iss.date_due, INTERVAL 10 DAY)
        )
        LEFT JOIN kemnersaker k ON (k.borrowernumber=b.borrowernumber)
        WHERE b.categorycode IN ('B',
                                 'SKO',
                                 'BHG')
          AND k.issue_id IS NULL
          AND bd.type = 'OVERDUES'
        GROUP BY b.cardnumber HAVING issuecount = 0
      ) niceperson USING (borrower_debarment_id);

    UPDATE borrowers b
    JOIN
      ( SELECT b.borrowernumber, COUNT(iss.issue_id) AS issuecount
        FROM borrowers b
        LEFT JOIN borrower_debarments bd USING(borrowernumber)
        LEFT JOIN issues iss ON ( iss.borrowernumber=b.borrowernumber
              AND DATE(NOW()) > DATE_ADD(iss.date_due, INTERVAL 10 DAY) )
        LEFT JOIN kemnersaker k ON (k.borrowernumber=b.borrowernumber)
        WHERE b.categorycode IN ('B',
                                 'SKO',
                                 'BHG')
          AND bd.borrowernumber IS NULL
          AND k.issue_id IS NULL
          AND (b.debarred IS NOT NULL
               OR b.debarred != "")
          AND b.debarredcomment LIKE 'OVERDUES_PROCESS%'
        GROUP BY b.cardnumber HAVING issuecount = 0
      ) niceperson USING (borrowernumber)
    SET b.debarred = NULL, b.debarredcomment = NULL;

    SELECT ROW_COUNT();
EOF`"
    report+="Unblocking juveniles with overdue restriction:\t${RES}\n"
}

unblock_juveniles_with_kemnersak
unblock_juveniles_with_overdues
echo -e ${report}
