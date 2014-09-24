########
# RUN KOHA WEBINSTALLER
# Update koha syspref 'Version' manually, needed to bypass webinstaller
# Update database if not up to date with koha-common version
# Should not run it already up to date
########
watir:
  pkg.installed:
  - pkgs:
    - ruby1.9.1-dev
    - phantomjs
  gem.installed:
    - name: watir-webdriver
    - require:
      - pkg: watir

/usr/local/bin/KohaWebInstallAutomation.rb:
  file.managed:
    - source: {{ pillar['koha']['saltfiles'] }}/KohaWebInstallAutomation.rb

run_webinstaller:
  cmd.script:
    - source: {{ pillar['koha']['saltfiles'] }}/updatekohadbversion.sh
    - stateful: True
    - env:
      - URL: "http://192.168.50.10:8081"
      - USER: {{ pillar['koha']['adminuser'] }}
      - PASS: {{ pillar['koha']['adminpass'] }}
      - INSTANCE: {{ pillar['koha']['instance'] }}
    - require:
      - pkg: watir
    - watch:
      - file: /usr/local/bin/KohaWebInstallAutomation.rb
