#!/bin/sh
# /cronjobs/send_reports.sh [-e email] [-e email]
#
# This cronjob runs saved reports and sends result to emails

### Cronjobber til kemner

usage() {
  echo "\nUsage:\n$0 [-e email] [-e email] [-s]\n"
  exit 1
}

send_reports() {
    local OPT="$1"
    local WHEN=`date +%F -d 'yesterday'`
    local CMD="koha-foreach --enabled /usr/share/koha/bin/cronjobs/runreport.pl ${OPT} -a --format=csv"
    # 25 - Rapport over innleverte medier som hadde status Regning
    $CMD --subject="${WHEN}_rapport_over_innleverte_medier_med_purring" 25
    # 26 - Sammendrag over innleverte medier med status Regning
    $CMD --subject "${WHEN}_sammendrag_innleverte_medier_med_purring" 26
    # 28 - Erstatninger - Kategorier B,V,I som hadde 35 dager over forfall
    $CMD --subject "${WHEN}_rapport_medier_35_dager_over_forfall" 28
    # 29 - Purregebyrer - Kategorier B,V,I som hadde 35 dager over forfall
    $CMD --subject "${WHEN}_rapport_purregebyrer_35_dager_over_forfall" 29
    # 30 - Innleverte medier for 2 dager siden som hadde status Forlengst forfalt
    $CMD --subject "${WHEN}_rapport_innleverte_medier_forlengst_forfalt" 30
}

while getopts ":e:s" opt; do
  case ${opt} in
    "")
    usage
    ;;
  e)
    send_reports --to=${OPTARG}
    ;;
  s)
    send_reports --store-results
    ;;
  \?)
    usage
    ;;
  esac
done
