########
# APACHE
########

# install_apache2:
#   pkg.installed:
#     - name: libapache2-mpm-itk
#     - require_in:
#       - pkg: apache2

apache2:
  pkg.installed

/etc/apache2/ports.conf:
  file.append:
    - text:
      - Listen 8080
      - Listen 8081
    - stateful: True
    - require:
      - pkg: apache2

apacheconfig:
  file.managed:
    - name: /etc/apache2/sites-available/{{ pillar['koha']['instance'] }}.conf
    - source: {{ pillar['koha']['saltfiles'] }}/apache.tmpl
    - template: jinja
    - context:
      OpacPort: 8080
      IntraPort: 8081
      ServerName: {{ pillar['koha']['instance'] }}
    - require:
      - pkg: apache2

disable_default:
  cmd.run:
    - name: sudo a2dissite default || true

sudo a2enmod rewrite:
  cmd.run:
    - require:
      - pkg: apache2

# Temporary hack to build on 14.04 due to apache mpm failure

# sudo a2dismod mpm_event || true:
#   cmd.run:
#     - require:
#       - pkg: apache2

# sudo a2dismod mpm_itk || true:
#   cmd.run:
#     - require:
#       - pkg: apache2

# sudo a2dismod mpm_prefork || true:
#   cmd.run:
#     - require:
#       - pkg: apache2

# sudo a2enmod mpm_itk || true:
#   cmd.run:
#     - require:
#       - pkg: apache2

sudo a2enmod cgi:
  cmd.run:
    - require:
      - pkg: apache2

sudo a2dissite 000-default:
  cmd.run:
    - require:
      - pkg: apache2

apache2_service:
  service.running:
    - name: apache2
    - require:
      - pkg: apache2
      - cmd: sudo a2enmod rewrite
      - cmd: sudo a2enmod cgi
      - cmd: sudo a2dissite 000-default
      - file: /etc/apache2/ports.conf
