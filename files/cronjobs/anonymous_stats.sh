#!/bin/sh
# /cronjobs/anonymous_stats.sh --days
#
# This cronjob creates anonymous stats and populates table anonymous_stats
# for issues that are due for batch_anonymize

usage() {
  echo -e "\nUsage:\n$0 [-d|--days] \n"
  exit 1
}

create_anonymous_stats() {
    local DAYS=$1
    cat <<-EOF | koha-mysql $(koha-list --enabled)
        /*
         *   create table anonymous_stats (unless exists)
         */
        CREATE TABLE IF NOT EXISTS anonymous_stats (
          old_issue_id int(11) NOT NULL,
          itemnumber int(11) DEFAULT NULL,
          returnbranch varchar(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT '',
          age int(3) DEFAULT NULL,
          sex varchar(1) COLLATE utf8_unicode_ci DEFAULT NULL,
          zipcode varchar(25) COLLATE utf8_unicode_ci DEFAULT NULL,
          homebranch varchar(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT '',
          categorycode varchar(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT '',
          timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (old_issue_id),
          KEY stats_itemidx (itemnumber),
          KEY stats_ageidx (age),
          KEY stats_sexidx (sex),
          KEY stats_zipidx (zipcode),
          KEY stats_returnbranchidx (returnbranch),
          KEY stats_homebranchidx (homebranch),
          KEY stats_catidx (categorycode)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
EOF
    echo "creating anonymous stats for issues $DAYS days old ..."
    QUERY="INSERT INTO anonymous_stats
          (old_issue_id, itemnumber, returnbranch, age, sex, zipcode, homebranch, categorycode)
        SELECT old_issues.issue_id,
            old_issues.itemnumber,
            old_issues.branchcode AS returnbranch,
            TIMESTAMPDIFF(YEAR, borrowers.dateofbirth, CURDATE()) AS age,
            borrowers.sex,
            borrowers.zipcode,
            borrowers.branchcode AS homebranch,
            borrowers.categorycode 
        FROM old_issues
        LEFT JOIN borrowers ON (borrowers.borrowernumber=old_issues.borrowernumber)
        WHERE (TO_DAYS(now()) - TO_DAYS(old_issues.returndate)) = $DAYS;"
    RES=`echo $QUERY | koha-mysql $(koha-list --enabled) -vv`
    echo "$RES"
}

case "$1" in
    "")
    usage
    ;;
  --days|-d)
    shift
    create_anonymous_stats $1
    shift
    ;;
  --help|-h)
    usage
    ;;
esac
