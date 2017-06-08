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
       LEFT JOIN issues iss ON (iss.borrowernumber=bd.borrowernumber)
       WHERE b.categorycode='B'
         AND bd.type = 'MANUAL'
       GROUP BY b.cardnumber HAVING issuecount = 0
       AND bd.comment IN ('Sendt til kemner',
                          'Regning') ) niceperson USING (borrowernumber)
    SET b.debarred = NULL;

    DELETE bd
    FROM borrower_debarments bd
    JOIN
      ( SELECT bd.*,
               COUNT(iss.issue_id) AS issuecount
       FROM borrower_debarments bd
       JOIN borrowers b ON (b.borrowernumber=bd.borrowernumber)
       JOIN kemnersaker k ON (k.borrowernumber=bd.borrowernumber)
       LEFT JOIN issues iss ON (iss.borrowernumber=bd.borrowernumber)
       WHERE b.categorycode='B'
         AND bd.type = 'MANUAL'
       GROUP BY b.cardnumber HAVING issuecount = 0
       AND bd.comment IN ('Sendt til kemner',
                          'Regning') ) niceperson USING (borrowernumber);

    SELECT ROW_COUNT();
EOF`"
  report+="Unblocking juveniles with kemnersak:\t${RES}\n"
}

unblock_juveniles_with_overdues() {
  # Remove 'debarred' on patrons in category 'B'
  # with no more issues but which are blocked due to restriction set by overdue provess
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE borrowers b
    JOIN
      ( SELECT bd.*,
               COUNT(iss.issue_id) AS issuecount
       FROM borrower_debarments bd
       JOIN borrowers b ON (b.borrowernumber=bd.borrowernumber)
       LEFT JOIN issues iss ON (iss.borrowernumber=bd.borrowernumber)
       WHERE b.categorycode='B'
       GROUP BY b.cardnumber HAVING issuecount = 0
       AND bd.type = 'OVERDUES' ) niceperson USING (borrowernumber)
    SET b.debarred = NULL;

    DELETE bd
    FROM borrower_debarments bd
    JOIN
      ( SELECT bd.*,
               COUNT(iss.issue_id) AS issuecount
       FROM borrower_debarments bd
       JOIN borrowers b ON (b.borrowernumber=bd.borrowernumber)
       LEFT JOIN issues iss ON (iss.borrowernumber=bd.borrowernumber)
       WHERE b.categorycode='B'
       GROUP BY b.cardnumber HAVING issuecount = 0
       AND bd.type = 'OVERDUES' ) niceperson USING (borrowernumber);

    SELECT ROW_COUNT();
EOF`"
    report+="Unblocking juveniles with overdue restriction:\t${RES}\n"
}

unblock_juveniles_with_kemnersak
unblock_juveniles_with_overdues
echo -e ${report}
