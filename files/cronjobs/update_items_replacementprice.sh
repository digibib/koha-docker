#!/bin/sh
# /root/update_items_replacementprice.sh
# updates replacementprice based on mediaType,audience and publicationYear -- 

cat <<-EOF | koha-mysql $(koha-list --enabled) 
	UPDATE items i
	LEFT JOIN biblioitems b ON (i.biblionumber=b.biblionumber)
	SET i.replacementprice = (
	  SELECT 
	  CASE EXTRACTVALUE(marcxml, '//record/datafield[@tag="337"]/subfield[@code="a"]/text()') /* mediaType */
	    WHEN 'Bok' THEN
	      CASE
	        WHEN EXTRACTVALUE(marcxml, '//record/datafield[@tag="260"]/subfield[@code="c"]/text()') < '1900' THEN '1500.00' /* publicationYear */
	        WHEN EXTRACTVALUE(marcxml, '//record/datafield[@tag="385"]/subfield[@code="a"]/text()') = 'Barn' THEN '250.00' /* audience */
	        ELSE '400.00'
	      END
	    WHEN 'Film' THEN
	      CASE
	        WHEN EXTRACTVALUE(marcxml, '//record/datafield[@tag="385"]/subfield[@code="a"]/text()') = 'Barn' THEN '250.00'
	        ELSE '300.00'
	      END
	    WHEN 'Tegneserier' THEN '250.00'
	    WHEN 'Musikkopptak' THEN '300.00'
	    WHEN 'Lydbok' THEN '400.00'
	    WHEN 'Språkkurs' THEN '500.00'
	    WHEN 'Dataspill' THEN '500.00'
	    WHEN 'Periodika' THEN '100.00'
	    WHEN 'Noter' THEN '400.00'
	    WHEN 'Brettspill' THEN '500.00'
	    ELSE '200,00' /* a sensible default */
	  END
	)
	WHERE i.biblionumber=b.biblionumber;
EOF