##########
# KOHA PLACK
##########

perl_deps:
  pkg.installed:
    - pkgs:
      - libplack-perl
      - libcgi-emulate-psgi-perl
      - libcgi-compile-perl
      - libdevel-nytprof-perl
      - cpanminus
      - dh-make-perl

/usr/share/koha/intranet/intra.psgi:
  file.managed:
    - source: salt://koha/files/intra.psgi
    - mode: 755
    - require:
       - pkg: perl_deps

install_perl_modules:
  cmd.run:
    - name: cpanm Plack::Middleware::Rewrite Plack::Middleware::Debug
    - require:
      - pkg: perl_deps