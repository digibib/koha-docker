#!/bin/sh
koha-mysql $(koha-list --enabled) -N -B -e "SELECT biblioitemnumber,GROUP_CONCAT(DISTINCT holdingbranch) FROM items GROUP BY biblioitemnumber;"
