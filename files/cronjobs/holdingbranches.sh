#!/bin/sh
koha-mysql $(koha-list --enabled) -N -B -e "SELECT biblioitemnumber,GROUP_CONCAT(DISTINCT homebranch) FROM items GROUP BY biblioitemnumber;"
