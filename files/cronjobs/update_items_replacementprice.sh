#!/bin/sh
# /cronjobs/update_items_replacementprice.sh
# updates replacementprice based on mediaType,audience

report="REPORT FROM CRONJOB update_items_replacementprice.sh\n"

RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1

    UPDATE items i
    JOIN
      (SELECT biblionumber,
              CASE EXTRACTVALUE(metadata, '//record/datafield[@tag="337"]/subfield[@code="a"]/text()') /* mediaType */
                  WHEN 'Bok' THEN CASE
                                      WHEN EXTRACTVALUE(metadata, '//record/datafield[@tag="385"]/subfield[@code="a"]/text()') = 'Voksne' THEN '450.00' /* audience */
                                      ELSE '300.00'
                                  END
                  WHEN 'Film' THEN '300.00'
                  WHEN 'Tegneserie' THEN '250.00'
                  WHEN 'Musikkopptak' THEN '300.00'
                  WHEN 'Lydbok' THEN '450.00'
                  WHEN 'Språkkurs' THEN '500.00'
                  WHEN 'Spill' THEN '500.00'
                  WHEN 'Periodika' THEN '100.00'
                  WHEN 'Noter' THEN '250.00'
                  ELSE NULL
              END AS price
       FROM biblio_metadata) tmp USING(biblionumber)
    SET i.replacementprice = tmp.price
    WHERE tmp.price IS NOT NULL;

    SELECT ROW_COUNT();
EOF`"

report+="Updated items replacementprice:\t${RES}\n"