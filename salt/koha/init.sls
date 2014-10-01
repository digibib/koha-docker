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
      - apache2
    - skip_verify: True
