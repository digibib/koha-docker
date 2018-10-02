#!/bin/sh
# /cronjobs/set_itemtype.sh
# update itemtype based on mediaType,format

RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1

    UPDATE biblioitems
JOIN (
    SELECT biblionumber, CASE
    WHEN mediatype='Lydbok' THEN 'LYDBOK'
    WHEN mediatype='Bok' THEN 'BOK'
    WHEN mediatype='Tegneserie' THEN 'BOK'
    WHEN mediatype='E-bok' THEN 'EBOK'
    WHEN mediatype='Film' THEN 'FILM'
    WHEN mediatype='Spill' THEN 'SPILL'
    WHEN mediatype='Språkkurs' THEN 'SPRAAKKURS'
    WHEN mediatype='Musikkopptak' THEN 'MUSIKK'
    WHEN mediatype='Periodika' THEN 'PERIODIKA'
    WHEN mediatype='Noter' THEN 'NOTER'
    WHEN mediatype='Andre' THEN
        CASE
        WHEN format='CD-ROM' THEN 'SPILL'
        WHEN format='CD' THEN 'LYDBOK'
        WHEN format='DVD-ROM' THEN 'SPILL'
        WHEN format='Dias' THEN 'REALIA'
        WHEN format='Kart' THEN 'KART'
        WHEN format='Musikkinstrument' THEN 'REALIA'
        ELSE 'BOK'
        END
    ELSE 'BOK'
    END AS 'itemtype'
    FROM (
    SELECT biblioitems.biblionumber,
            ExtractValue(metadata, '//datafield[@tag="337"]/subfield[@code="a"]') AS mediatype,
            ExtractValue(metadata, '//datafield[@tag="338"]/subfield[@code="a"]') AS format
    FROM biblioitems JOIN biblio_metadata USING(biblionumber)
    ) x
) v ON v.biblionumber = biblioitems.biblionumber
SET biblioitems.itemtype=v.itemtype
WHERE biblioitems.itemtype IS NULL;

    SELECT ROW_COUNT();
EOF`"

echo "REPORT FROM CRONJOB set_itemtype.sh\nUpdated biblioitems missing itemtype: " $RES
