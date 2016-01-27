
* enable cronjob to generate static collectd graphs

```
cat >> /var/spool/cron/crontabs/om <<'EOF'
# m h  dom mon dow   command
*/5 * * * * /opt/openmetrics/scripts/collectd2html.pl >> /opt/openmetrics/logs/collectd2html.log 2>&1
EOF
# permission?
chown om:crontab /var/spool/cron/crontabs/om

```

* add /etc/sudoers entry for om-user to execute nmap, traceroute and whois without password

```
om ALL=NOPASSWD:/usr/bin/traceroute,/usr/bin/whois,/usr/bin/nmap
```
