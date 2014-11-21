# the nginx server instance
server {
    listen      80 default;
    server_name _;
    access_log  /var/log/nginx/access.${RIFOR_APP_NAME}.log;
    error_log   /var/log/nginx/error.${RIFOR_APP_NAME}.log;
    root        /var/www/html;

    # access munin
    location /munin {
      access_log /var/log/nginx/access.munin.log;
      error_log  /var/log/nginx/error.munin.log;
      alias      /var/cache/munin/www;
      index      index.html index.htm;

      auth_basic           "Restricted";
      auth_basic_user_file /etc/nginx/htpasswd;
    }

    # nginx status
    location /nginx_status {
      stub_status on;
      access_log  off;
      allow       127.0.0.1;
      deny        all;
    }
 }
