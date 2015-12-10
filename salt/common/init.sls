install_common_pkgs:
  pkg.installed:
    - pkgs:
      - git
    - skip_verify: True
