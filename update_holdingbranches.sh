#!/bin/bash

if [ ! -f /var/lib/state/old.tsv ]; then
	/root/holdingbranches.sh > /var/lib/state/old.tsv
fi

/root/holdingbranches.sh > /var/lib/state/new.tsv

diff --changed-group-format='%<' --unchanged-group-format='' /var/lib/state/new.tsv /var/lib/state/old.tsv > /var/lib/state/diff.tsv

IFS=$'\t'
while read RECORDID BRANCHES; do
  curl -X POST "http://services:8005/search/work/reindex?recordId=$RECORDID&branches=$BRANCHES"
done </var/lib/state/diff.tsv

mv /var/lib/state/new.tsv /var/lib/state/old.tsv