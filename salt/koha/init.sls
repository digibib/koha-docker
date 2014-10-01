##########
# KOHA Dependencies
##########

installdeps:
  pkg.installed:
    - pkgs:
      - python-software-properties
      - software-properties-common
      - libnet-ssleay-perl 
      - libcrypt-ssleay-perl
      - libcgi-application-dispatch-perl
    - skip_verify: True
