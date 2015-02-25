stop_devSIP:
  cmd.run:
    - name: "screen -S kohadev-sip -X quit ; ps aux | grep IC4/SIP | grep -v grep | kill `awk '{print $2}'`"
