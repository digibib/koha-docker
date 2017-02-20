#!/bin/sh
koha-mysql $(koha-list --enabled) -N -B -e "SELECT biblionumber,GROUP_CONCAT(DISTINCT homebranch) FROM items GROUP BY biblionumber;"
