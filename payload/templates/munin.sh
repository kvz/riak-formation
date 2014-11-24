# dbdir   /var/lib/munin
# htmldir /var/cache/munin/www
# logdir  /var/log/munin
# rundir  /var/run/munin
# tmpldir /etc/munin/templates

includedir /etc/munin/munin-conf.d

[${RIFOR_HOSTNAME}]
    address 127.0.0.1
    use_node_name yes

#graph_period minute
#graph_strategy cgi
#munin_cgi_graph_jobs 6
#cgiurl_graph /cgi-bin/munin-cgi-graph
#max_graph_jobs 6
#contact.nagios.command /usr/bin/send_nsca nagios.host.comm -c /etc/nsca.conf
