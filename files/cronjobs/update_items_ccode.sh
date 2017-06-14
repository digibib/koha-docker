#!/bin/bash
# /cronjobs/update_items_ccode.sh
report="REPORT FROM CRONJOB update_items_ccode.sh\n"

blue_zone() {
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE items
    JOIN biblio_metadata USING(biblionumber)
    SET ccode='5' /* BLÅ SONE */
    WHERE (ccode=''
           OR ccode IS NULL)
      AND items.homebranch='hutl'
      AND /* REGLER */ ((coded_location_qualifier='vo'
                         AND (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP 'Oslo' /* Oslo-samlingen  */
                              OR IF(LOCATION IS NOT NULL , LOCATION='Oslohylla', 0)))
                        OR (coded_location_qualifier='vo'
                            AND IF(LOCATION IS NOT NULL , LOCATION REGEXP BINARY 'SLEKT', 0)) /* Slekt-samlingen */
                        OR (coded_location_qualifier='vo'
                            AND ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP BINARY 'BI') /* Biografier */
                        OR (coded_location_qualifier='vo'
                            AND /* Avgrens til deweynumre ihht wiki */ (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^0[0-9][0-9]'
                                                                        OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^1[0-9][0-9]'
                                                                        OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^2[0-9][0-9]'
                                                                        OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^3[0-9][0-9]'
                                                                        OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^65[0-9]'
                                                                        OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^8[0-9][0-9]'
                                                                        OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^90[0-9]'
                                                                        OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^9[2-9][0-9]'))
                        OR /* DFB Fag */ (coded_location_qualifier='vo'
                                          AND substring(ExtractValue(metadata,'//controlfield[@tag="008"]'), 33,2) REGEXP ('0')
                                          AND ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP BINARY '^[A-Z][A-Z][A-Z] ')
                        OR /* Lydbøker Fag */ (coded_location_qualifier='vo'
                                               AND substring(ExtractValue(metadata,'//controlfield[@tag="008"]'), 33,2) REGEXP ('0')
                                               AND ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') = 'Lydbok'))
      AND NOT /* UNNTAK */ (/* Ting fra Lilla sone  */ (/* Eventyr */ ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^398.2')
                            OR /* Ting fra Gul sone  */ ((items.coded_location_qualifier IN ('vo',
                                                                                             'ba')
                                                          AND LOCATION IN ('PopKult',
                                                                           'VERKSTED',
                                                                           'FANTASTung',
                                                                           'FANTASYung',
                                                                           'Fantasy',
                                                                           'Fant',
                                                                           'Sci',
                                                                           'SciFi',
                                                                           'SF',
                                                                           'F')) /* Basert på plasseringskoder */
                                                         OR (coded_location_qualifier='vo'
                                                             AND ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') IN ('Tegneserie',
                                                                                                                                         'Spill',
                                                                                                                                         'Film')) /* Basert på medietyper: Tegneserier, spill og film fra voksenavdelingen */
                                                         OR (IF(LOCATION IS NOT NULL , LOCATION REGEXP BINARY 'UNG' , 0)
                                                             AND ExtractValue(metadata,'//datafield[@tag="041"]/subfield[@code="a"]') REGEXP 'eng|nob|nno|nor')) /* Location UNG og språk norske eller engelsk*/
                            OR /* Ting fra Rød sone  */ ((ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP '[[:<:]](TA|TB)[[:>:]]')) /* Inkluder alt som er lettlest  (også faglitteratur), dvs. ta|tb i 090b*/
                            OR /* Ting fra Grønn sone  */ ((IF(LOCATION IS NOT NULL , LOCATION REGEXP 'MILJ.|Milj.hylla', 0)))) /* Miljø-samlingen  */ ;
    SELECT ROW_COUNT();
EOF`"
    report+="Updated items blue zone:\t${RES}\n"
}

purple_zone() {
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE items
    JOIN biblio_metadata USING(biblionumber)
    SET ccode='2'
    WHERE (ccode=''
           OR ccode IS NULL)
      AND items.homebranch='hutl'
      AND /* REGLER */ ( /* Nesten alt fra barneavdelingen */ (coded_location_qualifier='ba')
                        OR /* Eventyr fra voksenavdelingen */ (coded_location_qualifier='vo'
                                                               AND ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^398.2') )
      AND NOT /* UNNTAK */ ( /* Ting fra Rød sone  */ ( /* Inkluder alt som er lettlest  (også faglitteratur), dvs. ta|tb i 090b*/ (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP '[[:<:]](TA|TB)[[:>:]]') )
                    OR /* Ting fra Gul sone - implementert i hovedregel*/ (items.coded_location_qualifier IN ('ba')
                                                                           AND LOCATION IN ('PopKult',
                                                                                            'VERKSTED',
                                                                                            'FANTASTung',
                                                                                            'FANTASYung'))
                    OR (IF(LOCATION IS NOT NULL , LOCATION REGEXP BINARY 'UNG' , 0)
                        AND ExtractValue(metadata,'//datafield[@tag="041"]/subfield[@code="a"]') REGEXP 'eng|nob|nno|nor') /* Ting fra Blå sone - utgår */ /* Ting fra Grønn sone - utgår */ ) ;
    SELECT ROW_COUNT();
EOF`"
    report+="Updated items purple zone:\t${RES}\n"
}

red_zone() {
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE items
    JOIN biblio_metadata USING(biblionumber)
    SET ccode='1'
    WHERE (ccode=''
           OR ccode IS NULL)
      AND items.homebranch='hutl'
      AND coded_location_qualifier='vo'
      AND /* REGLER */ ( /* Avgrens til skjønn, basert på Marcpost*/ (substring(ExtractValue(metadata,'//controlfield[@tag="008"]'), 33,2) REGEXP ('1')
                                                                      AND NOT ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^398.2')
                        OR /* Inkluder alt som er lettlest  (også faglitteratur), dvs. ta|tb i 090b*/ (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP '[[:<:]](TA|TB)[[:>:]]') )
      AND NOT /* UNNTAK */ ( /* Ting fra Lilla sone - utgår */ /* Ting fra Gul sone  */ ( /* Location UNG og språk norske eller engelsk*/ (IF(LOCATION IS NOT NULL , LOCATION REGEXP BINARY 'UNG' , 0)
                                                                       AND ExtractValue(metadata,'//datafield[@tag="041"]/subfield[@code="a"]') REGEXP 'eng|nob|nno|nor')
                     OR /* Basert på plasseringskoder */ (items.coded_location_qualifier IN ('vo')
                                                          AND LOCATION IN ('PopKult',
                                                                           'VERKSTED',
                                                                           'FANTASTung',
                                                                           'FANTASYung',
                                                                           'Fantasy',
                                                                           'Fant',
                                                                           'Sci',
                                                                           'SciFi',
                                                                           'SF',
                                                                           'F'))
                     OR (items.coded_location_qualifier IN ('ba')
                         AND LOCATION IN ('PopKult',
                                          'VERKSTED',
                                          'FANTASTung',
                                          'FANTASYung'))
                     OR /* Basert på medietyper: Tegneserier, spill og film fra voksenavdelingen */ (coded_location_qualifier='vo'
                                                                                                     AND ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') IN ('Tegneserie',
    'Spill',
    'Film')) ) ) ;
    SELECT ROW_COUNT();
EOF`"
    report+="Updated items red zone:\t\t${RES}\n"
}

green_zone() {
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE items
    JOIN biblio_metadata USING(biblionumber)
    SET items.ccode='4'
    WHERE (ccode=''
           OR ccode IS NULL)
      AND items.homebranch='hutl'
      AND items.coded_location_qualifier='vo'
      AND /* REGLER */ ( /* Basert på Deweynummer */ (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^4[0-9][0-9]'
                                                      OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^5[0-9][0-9]'
                                                      OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^6[0-4][0-9]'
                                                      OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^6[6-9][0-9]'
                                                      OR (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^7[0-7][0-9]'
                                                          AND NOT ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^741.5')
                                                      OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^79[6-9]'
                                                      OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^91[0-9]')
                        OR /* Miljø-samlingen  */ (IF(LOCATION IS NOT NULL , LOCATION REGEXP 'MILJ.|Milj.hylla' , 0)) )
      AND NOT /* UNNTAK */ ( /* Ting fra Lilla sone  - unødvendig */ /* Ting fra Gul sone  */ ( (IF(LOCATION IS NOT NULL , LOCATION REGEXP BINARY 'UNG' , 0)
                 AND ExtractValue(metadata,'//datafield[@tag="041"]/subfield[@code="a"]') REGEXP 'eng|nob|nno|nor')
               OR /* Basert på plasseringskoder */ (items.coded_location_qualifier IN ('vo',
                                                                                       'ba')
                                                    AND LOCATION IN ('PopKult',
                                                                     'VERKSTED',
                                                                     'FANTASTung',
                                                                     'FANTASYung',
                                                                     'Fantasy',
                                                                     'Fant',
                                                                     'Sci',
                                                                     'SciFi',
                                                                     'SF',
                                                                     'F'))
               OR /* Basert på medietyper: Tegneserier, spill og film fra voksenavdelingen */ (coded_location_qualifier='vo'
                                                                                               AND ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') IN ('Tegneserie','Spill','Film')) )
                            OR /* Ting fra Blå sone  */ ( /* Oslo-samlingen  */ (coded_location_qualifier='vo'
                                                                                 AND (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP 'Oslo'
                                                                                      OR IF(LOCATION IS NOT NULL , LOCATION='Oslohylla', 0)))
                                                         OR /* Slekt-samlingen */ (coded_location_qualifier='vo'
                                                                                   AND IF(LOCATION IS NOT NULL , LOCATION REGEXP BINARY 'SLEKT', 0))
                                                         OR /* Biografier */ (coded_location_qualifier='vo'
                                                                              AND ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP BINARY 'BI')
                                                         OR /* DFB Fag */ (coded_location_qualifier='vo'
                                                                           AND substring(ExtractValue(metadata,'//controlfield[@tag="008"]'), 33,2) REGEXP ('0')
                                                                           AND ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP BINARY '^[A-Z][A-Z][A-Z] ')
                                                         OR /* Lydbøker Fag */ (coded_location_qualifier='vo'
                                                                                AND substring(ExtractValue(metadata,'//controlfield[@tag="008"]'), 33,2) REGEXP ('0')
                                                                                AND ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') = 'Lydbok') )
                            OR /* Ting fra Rød sone  */ ( /* Inkluder alt som er lettlest  (også faglitteratur), dvs. ta|tb i 090b*/ (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP '[[:<:]](TA|TB)[[:>:]]') ) ) ;
    SELECT ROW_COUNT();
EOF`"
    report+="Updated items green zone:\t${RES}\n"
}

yellow_zone() {
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE items
    JOIN biblio_metadata USING(biblionumber)
    SET ccode='3'
    WHERE (ccode=''
           OR ccode IS NULL)
      AND items.homebranch='hutl'
      AND /* REGLER */ ( /* Alt fra musikkavdelingen */ (coded_location_qualifier='mus')
                        OR /* Location UNG og språk norske eller engelsk*/ (IF(LOCATION IS NOT NULL , LOCATION REGEXP BINARY 'UNG' , 0)
                                                                            AND ExtractValue(metadata,'//datafield[@tag="041"]/subfield[@code="a"]') REGEXP 'eng|nob|nno|nor')
                        OR /* Basert på Deweynummer */ (coded_location_qualifier IN ('vo',
                                                                                     'mus')
                                                        AND (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^741.5'
                                                             OR ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP '^79[0-5]'))
                        OR /* Basert på plasseringskoder */ (items.coded_location_qualifier IN ('vo')
                                                             AND LOCATION IN ('PopKult',
                                                                              'VERKSTED',
                                                                              'FANTASTung',
                                                                              'FANTASYung',
                                                                              'Fantasy',
                                                                              'Fant',
                                                                              'Sci',
                                                                              'SciFi',
                                                                              'SF',
                                                                              'F'))
                        OR (items.coded_location_qualifier IN ('ba')
                            AND LOCATION IN ('PopKult',
                                             'VERKSTED',
                                             'FANTASTung',
                                             'FANTASYung'))
                        OR /* Basert på medietyper: Tegneserier, spill og film fra voksenavdelingen */ (coded_location_qualifier='vo'
                                                                                                        AND ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') IN ('Tegneserie',
                                                                                                                                                                                    'Spill',
                                                                                                                                                                                    'Film')) )
      AND NOT /* UNNTAK */ ( /* Ting fra Lilla sone  - utgår */ /* Ting fra Rød sone  */ ( /* Inkluder alt som er lettlest  (også faglitteratur), dvs. ta|tb i 090b*/ (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP '[[:<:]](TA|TB)[[:>:]]') )
                            OR /* Ting fra Blå sone  */ ( /* DFB Fag */ (coded_location_qualifier='vo'
                                                                         AND substring(ExtractValue(metadata,'//controlfield[@tag="008"]'), 33,2) REGEXP ('0')
                                                                         AND ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="c"]') REGEXP BINARY '^[A-Z][A-Z][A-Z] ')
                                                         OR /* Lydbøker Fag */ (coded_location_qualifier='vo'
                                                                                AND substring(ExtractValue(metadata,'//controlfield[@tag="008"]'), 33,2) REGEXP ('0')
                                                                                AND ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') = 'Lydbok')
                                                         OR /* Oslo-samlingen  */ (coded_location_qualifier='vo'
                                                                                   AND (ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP 'Oslo'
                                                                                        OR IF(LOCATION IS NOT NULL, LOCATION='Oslohylla' , 0)
                                                                                        OR IF(LOCATION IS NOT NULL, LOCATION REGEXP BINARY '^OSLO' , 0)))
                                                         OR /* Slekt-samlingen */ (coded_location_qualifier='vo'
                                                                                   AND IF(LOCATION IS NOT NULL, LOCATION REGEXP BINARY 'SLEKT', 0))
                                                         OR /* Biografier */ (coded_location_qualifier='vo'
                                                                              AND ExtractValue(metadata,'//datafield[@tag="090"]/subfield[@code="b"]') REGEXP BINARY 'BI') )
                            OR /* Ting fra Grønn sone  */ ( /* Miljø-samlingen  */ (IF(LOCATION IS NOT NULL, LOCATION REGEXP 'MILJ.|Milj.hylla', 0)) ) ) ;
    SELECT ROW_COUNT();
EOF`"
    report+="Updated items yellow zone:\t${RES}\n"
}

magazinate() {
  local RES="`cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8 -N 2>&1
    UPDATE items
        JOIN biblio_metadata USING(biblionumber)
        SET ccode = CONCAT(ccode, 'm')
        WHERE items.homebranch='hutl'
          AND ccode IN ('1',
                        '2',
                        '3',
                        '4',
                        '5')
          AND ( IF(LOCATION IS NOT NULL , LOCATION REGEXP '[[:<:]](m|mq|bm|bmq|blm|blmq|um|umq|mag|magasin)[[:>:]]', 0)
               OR IF(LOCATION IS NOT NULL , LOCATION REGEXP 'm[0-9]', 0)
               OR IF(LOCATION IS NOT NULL , LOCATION REGEXP 'mq[0-9]', 0) ) ;
     SELECT ROW_COUNT();
EOF`"
    report+="Updated items put in magazine:\t${RES}\n"
}

blue_zone
purple_zone
red_zone
green_zone
yellow_zone
magazinate

echo -e ${report}
