#!bin/sh

# 1: System setup
sudo yum -y update
sudo timedatectl set-timezone Asia/Taipei
sudo yum -y install policycoreutils-python
sudo yum -y install httpd-tools

# 2: Java
# Oravle java in https://java.com/en/download/linux_manual.jsp; may need to change version link.
sudo wget -O /tmp/java-1-181.rpm http://javadl.oracle.com/webapps/download/AutoDL?BundleId=234461_96a7b8442fe848ef90c96a2fad6ed6d1
sudo rpm -ivh /tmp/java-1-181.rpm
java -version

# 3: ELK
# Version 6.x.
sudo bash -c 'cat << EOF > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF'

sudo yum -y install elasticsearch
sudo yum -y install kibana
sudo yum -y install logstash

sudo systemctl enable elasticsearch
sudo systemctl enable kibana
sudo systemctl enable logstash

sed -i 's/^#network.host:.*/network.host: localhost/g' /etc/elasticsearch/elasticsearch.yml

# 4: Network
sudo firewall-cmd --add-port=9200/tcp --permanent
sudo firewall-cmd --add-port=5601/tcp --permanent
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --reload
sudo semanage port -a -t http_port_t -p tcp 5601

sudo bash -c 'cat << EOF > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/$basearch/
gpgcheck=1
enabled=1
EOF'

sudo rpm --import nginx_signing.key
sudo yum -y install nginx

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/pki/tls/private/kibana-access.key -out /etc/pki/tls/certs/kibana-access.crt
sudo openssl dhparam -out /etc/pki/tls/certs/dhparam.pem 2048

sudo bash -c 'cat << EOF > /etc/nginx/conf.d/ssl.conf
upstream kibana {
    server localhost:5601 fail_timeout=0;
}
    
server {
    listen 80;
    listen [::]:80 ipv6only=on;
    return 301 https://$host$request_uri;
}
    
server {
    listen 443 default_server;
    listen            [::]:443;
    ssl on;
    ssl_certificate /etc/pki/tls/certs/kibana-access.crt;
    ssl_certificate_key /etc/pki/tls/private/kibana-access.key;
    ssl_dhparam /etc/pki/tls/certs/dhparam.pem;
    access_log            /var/log/nginx/nginx.access.log;
    error_log            /var/log/nginx/nginx.error.log;
    location / {
        auth_basic "Restricted";
        auth_basic_user_file /etc/nginx/conf.d/.kibana.htpasswd;
        proxy_pass http://localhost:5601/;
    }
}
EOF'


echo "Adding htpasswd for nginx." 
sudo htpasswd -c /etc/nginx/conf.d/kibana.htpasswd vrecle
