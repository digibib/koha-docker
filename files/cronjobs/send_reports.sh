#!/bin/bash
# /cronjobs/send_reports.sh [email] [email]
#
# This cronjob runs saved reports, store them and sends result to emails

### Cronjobber til kemner
WHEN=`date +%F -d 'yesterday'`
REPORTS=(
    "${WHEN}_rapport_over_innleverte_medier_med_purring.csv"
    "${WHEN}_rapport_medier_35_dager_over_forfall.csv"
    )

usage() {
  echo -e "\nUsage:\n$0 [-e|--email] \n"
  exit 1
}

send_reports() {
    local EMAIL="$1"
    local BOUNDARY="T/asfAY23523.34"
    { printf "%s\n" \
        "Subject: Kemnerrapporter ${WHEN}" \
        "From: no-reply@deichman.no" \
        "To: ${EMAIL}" \
        "Mime-Version: 1.0" \
        "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\"" \
        \
        "--${BOUNDARY}" \
        "Content-Type: text/plain" \
        "Content-Disposition: inline" \
        "" \
        "Vedlagt ligger rapporter for ${WHEN}";

    for REPORT in "${REPORTS[@]}"; do
        printf "%s\n" "--${BOUNDARY}" \
        "Content-Type: text/csv" \
        "Content-Transfer-Encoding: base64" \
        "Content-Disposition: attachment; filename=\"${REPORT}\""\
        "";
        base64 /var/lib/state/${REPORT}
        echo
    done
    printf '%s\n' "--${BOUNDARY}--"
    } | sendmail "${EMAIL}" -t -oi
}

save_reports() {
    # 28 - Erstatninger - Kategorier B,V,I som hadde 35 dager over forfall
    koha-shell -c '/usr/share/koha/bin/cronjobs/runreport.pl --format=csv --store-results 28' $KOHA_INSTANCE > /var/lib/state/${WHEN}_rapport_medier_35_dager_over_forfall.csv
    # 29 - Purregebyrer - Kategorier B,V,I som hadde 35 dager over forfall - append to previos report
    koha-shell -c '/usr/share/koha/bin/cronjobs/runreport.pl --format=csv --store-results 29' $KOHA_INSTANCE | tail -n+2 >> /var/lib/state/${WHEN}_rapport_medier_35_dager_over_forfall.csv
    # 45 - Rapport over innleverte medier som hadde status Regning eller Forlengst forfalt
    koha-shell -c '/usr/share/koha/bin/cronjobs/runreport.pl --format=csv --store-results 45' $KOHA_INSTANCE > /var/lib/state/${WHEN}_rapport_over_innleverte_medier_med_purring.csv
}

save_reports
case "$1" in
    "")
    usage
    ;;
  --email|-e)
    shift
    send_reports $1
    shift
    ;;
  --help|-h)
    usage
    ;;
esac
