Europe/Oslo:
  timezone.system:
    - utc: True

install_common_pkgs:
  pkg.installed:
    - pkgs:
      - language-pack-nb
      - openssh-server
      - git
    - skip_verify: True