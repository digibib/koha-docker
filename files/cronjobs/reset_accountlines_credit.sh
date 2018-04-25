#!/bin/sh
# /cronjobs/reset_accountlines_credit.sh
# Zeroes out credit on users that have paid and returned items for whom the
# library now owes money

report="REPORT FROM CRONJOB reset_accountlines_credit.sh\n"

add_accountlines_reversing_credit() {
  # Inserts lines into accountlines that reverse any patron credits
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    INSERT INTO accountlines (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding, timestamp)
    SELECT borrowernumber,
           MAX(accountno) + 1,
           DATE(NOW()),
           SUM(amountoutstanding) * -1,
           "Kreditt fjernet automatisk",
           "UNDO",
           0,
           NOW()
    FROM accountlines
    GROUP BY borrowernumber HAVING SUM(amountoutstanding) < 0;

    SELECT ROW_COUNT();
EOF`"
  report+="Unblocking juveniles with kemnersak:\t${RES}\n"
}

add_account_offset_credit() {
  # Inserts lines into account_offsets that reverse any patron credits
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    INSERT INTO account_offsets (debit_id, TYPE, amount, created_on)
    SELECT MAX(a.accountlines_id),
           "Reverse Payment",
           tmp.total * -1,
           NOW()
    FROM accountlines a
    JOIN
      (SELECT accountlines_id,
              borrowernumber,
              SUM(amountoutstanding) AS total
       FROM accountlines
       GROUP BY borrowernumber HAVING total < 0) tmp USING (borrowernumber)
    WHERE tmp.total < 0
    GROUP BY a.borrowernumber;
EOF`"
  report+="Unblocking juveniles with kemnersak:\t${RES}\n"
}

update_accountlines_amountoutstanding() {
  # Updates all relevant lines that have amountoutstanding
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE accountlines a
    JOIN ( SELECT accountlines_id,borrowernumber,SUM(amountoutstanding) AS total FROM accountlines GROUP BY borrowernumber HAVING total < 0 ) tmp USING (borrowernumber)
    SET a.amountoutstanding = 0, timestamp = NOW()
    WHERE a.amountoutstanding < 0
    AND tmp.total < 0;

    SELECT ROW_COUNT();
EOF`"
  report+="Unblocking juveniles with kemnersak:\t${RES}\n"
}

add_accountlines_reversing_credit()
add_account_offset_credit()
update_accountlines_amountoutstanding()
