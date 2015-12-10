base:
  '*':
    - common
    - koha
    - koha.apache2
    - koha.common
    - koha.sites-config
    - mysql.server  # need this to run createdb (which does more than create a db)
    - koha.createdb
    - koha.config # includes switching to db instance on ls.db
    - koha.webinstaller
    - cron
