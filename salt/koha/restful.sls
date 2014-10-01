##########
# KOHA RESTFUL API
##########

libcgi-application-dispatch-perl:
  pkg.installed

restful-git:
  git.latest:
    - name: https://github.com/digibib/koha-restful.git
    - rev: master
    - target: /usr/local/src/koha-restful

# PROD
/usr/share/koha/lib/Koha/REST:
  file.symlink:
    - target: /usr/local/src/koha-restful/Koha/REST

/usr/share/koha/opac/cgi-bin/opac/rest.pl:
  file.symlink:
    - target: /usr/local/src/koha-restful/opac/rest.pl

