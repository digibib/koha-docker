watir:
  pkg.installed:
  - pkgs:
    - ruby1.9.1-dev
    - phantomjs
    - build-essential
  gem.installed:
    - name: watir-webdriver
    - require:
      - pkg: watir
