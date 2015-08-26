##########
#  CRON  #
##########

cron:
  pkg.installed

# Temporarily remove logrotate until Docker logrotate is handled properly in Docker
# https://sandro-keil.de/blog/2015/03/11/logrotate-for-docker-container/
disable logrotate:
  pkg.purged:
    - name: logrotate
