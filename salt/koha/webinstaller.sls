########
# RUN KOHA WEBINSTALLER
# Update koha syspref 'Version' manually, needed to bypass webinstaller
# Update database if not up to date with koha-common version
# Should not run it already up to date
########

/usr/local/bin/KohaWebInstallAutomation.pl:
  file.managed:
    - source: salt://koha/files/KohaWebInstallAutomation.pl

run_webinstaller:
  cmd.script:
    - source: salt://koha/files/updatekohadbversion.sh
    - stateful: True
    - cwd: /usr/share/koha/lib
    - shell: /bin/bash
    - env:
      - URL: "http://127.0.0.1:8081"
      - USER: {{ pillar['koha']['adminuser'] }}
      - PASS: {{ pillar['koha']['adminpass'] }}
      - INSTANCE: {{ pillar['koha']['instance'] }}
    - require:
      - file: /usr/local/bin/KohaWebInstallAutomation.pl
