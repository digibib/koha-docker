#!/bin/sh
# /cronjobs/auto_branchtransfer_automat_checkins.sh
# updates branchtransfers for items checked in with automat users
# sets `datearrived` to NOW if missing if there are no reserves on biblio
# and tobranch matches automat branch

cat <<-EOF | koha-mysql $(koha-list --enabled) --default-character-set=utf8
	UPDATE branchtransfers bt
	JOIN (
		SELECT 'autohb'   AS user, 'hutl' AS branch UNION
		SELECT 'autoblr'  AS user, 'fbol' AS branch UNION
		SELECT 'autofuru' AS user, 'ffur' AS branch UNION
		SELECT 'autogru'  AS user, 'fgry' AS branch UNION
		SELECT 'autohol'  AS user, 'fhol' AS branch UNION
		SELECT 'autolmb'  AS user, 'flam' AS branch UNION
		SELECT 'automaj'  AS user, 'fmaj' AS branch UNION
		SELECT 'autonyd'  AS user, 'fnyd' AS branch UNION
		SELECT 'autoopp'  AS user, 'fopp' AS branch UNION
		SELECT 'autoromm' AS user, 'frmm' AS branch UNION
		SELECT 'autoroa'  AS user, 'froa' AS branch UNION
		SELECT 'autostv'  AS user, 'fsto' AS branch UNION
		SELECT 'autotor'  AS user, 'ftor' AS branch UNION
		SELECT 'autotoy'  AS user, 'fgam' AS branch
	) aut ON (aut.user=bt.frombranch)
	JOIN branches br ON (br.branchcode=bt.frombranch)
	LEFT JOIN items i ON (i.itemnumber=bt.itemnumber)
	LEFT JOIN reserves res ON (res.biblionumber=i.biblionumber)
	SET bt.datearrived = NOW()
	WHERE bt.datearrived IS NULL
	AND res.biblionumber IS NULL
	AND bt.tobranch = aut.branch ;
EOF
