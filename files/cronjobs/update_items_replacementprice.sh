#!/bin/sh
# /root/update_items_replacementprice.sh
# updates replacementprice based on mediaType,audience and publicationYear -- 

cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8
	UPDATE items i
	LEFT JOIN biblioitems b ON (i.biblionumber=b.biblionumber)
	SET i.replacementprice = (
	  SELECT 
	  CASE EXTRACTVALUE(b.marcxml, '//record/datafield[@tag="337"]/subfield[@code="a"]/text()') /* mediaType */
	    WHEN 'Bok' THEN
	      CASE
	        WHEN EXTRACTVALUE(b.marcxml, '//record/datafield[@tag="385"]/subfield[@code="a"]/text()') = 'Voksne' THEN '450.00' /* audience */
	        ELSE '300.00'
	      END
	    WHEN 'Film' THEN '300.00'
	    WHEN 'Tegneserier' THEN '250.00'
	    WHEN 'Musikkopptak' THEN '300.00'
	    WHEN 'Lydbok' THEN '450.00'
	    WHEN 'Språkkurs' THEN '500.00'
	    WHEN 'Spill' THEN '500.00'
	    WHEN 'Dataspill' THEN '500.00'
	    WHEN 'Periodika' THEN '100.00'
	    WHEN 'Noter' THEN '250.00'
	    WHEN 'Brettspill' THEN '500.00'
	  END
	)
	WHERE i.biblionumber=b.biblionumber
	/* EXCLUDED: 'REALIA' */
	AND i.itype IN ('BOK', 'DAGSLAAN', 'EBOK', 'FILM', 'KART', 'LYDBOK', 'MUSIKK',
	'NOTER', 'PERIODIKA', 'SPILL', 'SPRAAKKURS', 'TOUKESLAAN', 'UKESLAAN');
EOF
