# remove binding to only 127.0.0.1

mysql_bind-address:
  file.replace:
    - name: /etc/mysql/my.cnf
    - pattern: '^bind-address'
    - repl: '# bind-address'
