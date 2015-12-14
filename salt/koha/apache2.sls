########
# APACHE
########

apache2:
  pkg.installed

/etc/apache2/ports.conf:
  file.append:
    - text:
      - Listen 8080
      - Listen 8081
    - require:
      - pkg: apache2

disable_default:
  cmd.run:
    - name: a2dissite default || true

a2enmod rewrite headers proxy_http cgi:
  cmd.run:
    - require:
      - pkg: apache2

a2dissite 000-default:
  cmd.run:
    - require:
      - pkg: apache2

apache2_service:
  service.running:
    - name: apache2
    - watch:
      - pkg: apache2
      - cmd: a2dissite 000-default
      - cmd: a2enmod rewrite headers proxy_http cgi