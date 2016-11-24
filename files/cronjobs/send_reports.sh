#!/bin/bash
# /cronjobs/send_reports.sh [email] [email]
#
# This cronjob runs saved reports, store them and sends result to emails

### Cronjobber til kemner
WHEN=`date +%F -d 'yesterday'`
REPORTDIR=/var/lib/state/reports
REPORTS=(
    "${WHEN}_rapport_over_innleverte_medier_med_purring.csv"
    "${WHEN}_rapport_medier_35_dager_over_forfall.csv"
    )
EMAILS=()

usage() {
  echo -e "\nUsage:\n$0 [-e|--email] \n"
  exit 1
}

send_reports() {
    local BOUNDARY="T/asfAY23523.34"
    for email in "${EMAILS[@]}"
    do
        echo "sending report to: ${email}"
        { printf "%s\n" \
            "Subject: Kemnerrapporter ${WHEN}" \
            "From: no-reply@deichman.no" \
            "To: ${email}" \
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
            base64 ${REPORTDIR}/${REPORT}
            echo
        done
        printf '%s\n' "--${BOUNDARY}--"
        } | sendmail "${email}" -t -oi
    done
}

save_reports() {
    mkdir -p $REPORTDIR
    echo "saving reports to $REPORTDIR"
    # 28 - Erstatninger - Kategorier B,V,I som hadde 35 dager over forfall
    /usr/share/koha/bin/cronjobs/runreport.pl --separator=";" --format=csv $STORE 28 > $REPORTDIR/${WHEN}_rapport_medier_35_dager_over_forfall.csv
    # 29 - Purregebyrer - Kategorier B,V,I som hadde 35 dager over forfall - append to previos report
    /usr/share/koha/bin/cronjobs/runreport.pl --separator=";" --format=csv $STORE 29 | tail -n+2 >> $REPORTDIR/${WHEN}_rapport_medier_35_dager_over_forfall.csv
    # 45 - Rapport over innleverte medier som hadde status Regning eller Forlengst forfalt
    /usr/share/koha/bin/cronjobs/runreport.pl --separator=";" --format=csv $STORE 45 > $REPORTDIR/${WHEN}_rapport_over_innleverte_medier_med_purring.csv
}

while [ "$1" != "" ]; do
    case "$1" in
      --email|-e)
        shift
        EMAILS+=("$1")
        ;;
      --store|-s)
        STORE="--store-results"
        ;;
      --help|-h)
        usage
        ;;
    esac
    shift
done

save_reports
send_reports
