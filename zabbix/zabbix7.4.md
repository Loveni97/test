这是centos8系统

agent安装：
rpm -ivh https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/7.4/stable/centos/8/x86_64/zabbix-agent-7.4.3-release1.el8.x86_64.rpm


rpm -Uvh https://repo.zabbix.com/zabbix/7.4/release/centos/8/noarch/zabbix-release-latest-7.4.el8.noarch.rpm



自定义zabbix.repo

cat > /etc/yum.repos.d/zabbix.repo <<'EOF'
[zabbix]
name=Zabbix Official Repository 7.4 - $basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/7.4/stable/centos/8/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/7.4/stable/centos/8/$basearch/RPM-GPG-KEY-ZABBIX-A14FE591

[zabbix-frontend]
name=Zabbix Official Repository frontend 7.4 - $basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/7.4/stable/centos/8/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/7.4/stable/centos/8/$basearch/RPM-GPG-KEY-ZABBIX-A14FE591
EOF

清缓存、刷源
dnf clean all
dnf makecache
dnf repolist | grep zabbix


直接装 Zabbix 7.4

dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent nginx mariadb-server



mysql -uroot -plinux0224 -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -uroot -plinux0224 -e 'show databases;'
mysql -uroot -plinux0224 -e "grant all privileges on zabbix.* to zabbix@localhost identified by 'linux0224';"
mysql -uroot -plinux0224 -e "SET GLOBAL log_bin_trust_function_creators = 1;"


4.导入服务端数据库
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql -uroot -plinux0224 zabbix

Zabbix 7.4 要求 MariaDB ≥ 10.5.0
echo "AllowUnsupportedDBVersions=1" >> /etc/zabbix/zabbix_server.conf




# 这是6.0版本


二、安装zabbix服务器前端和agent
1安装zabbix存储库
【6.4版本】
rpm -Uvh https://repo.zabbix.com/zabbix/6.4/rhel/8/x86_64/zabbix-release-6.4-1.el8.noarch.rpm
dnf clean all
【6.0版本】
rpm -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/8/x86_64/zabbix-release-6.0-4.el8.noarch.rpm
dnf clean all
2.切换PHP的DNF模块版本
dnf module switch-to php:7.4

3.安装Zabbix server,web前端，agent

dnf install zabbix-server-mysql zabbix-web-mysql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent

三、安装和配置数据库

cat > /etc/yum.repos.d/mariadb.repo <<'EOF'
[mariadb]
name = MariaDB
baseurl = https://yum.mariadb.org/10.6/rhel/8/x86_64
gpgkey = https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck = 1
enabled = 1
module_hotfixes = 1
EOF


dnf -y install mariadb-server && systemctl start mariadb && systemctl enable mariadb
#安装完成后启动并且设置为开机启动


3.设置mariadb数据库，创建zabbix库，存储监控数据，且创建账号
mysqladmin password linux0224
mysql -uroot -plinux0224 -e 'create database zabbix character set utf8 collate utf8_bin;'
mysql -uroot -plinux0224 -e 'show databases;'

创建用户账户，zabbix 密码是linux0224
给与权限是，zabbix这个用户，对于zabbix这个库下的所有表，都是最大权限
mysql -uroot -plinux0224 -e "grant all privileges on zabbix.* to zabbix@localhost identified by 'linux0224';"

4.导入服务端数据库
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uroot -plinux0224 zabbix
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix


 4.2配置php
 vim /etc/php.ini
 
post_max_size = 16M   #由8M改为16M
max_execution_time = 300   #由30改为300
max_input_time = 300   #由60改为300


4.3配置Nginx

vim /etc/nginx/conf.d/zabbix.conf
#listen 8080;
#server_name example.com; 

#这两行取消注释并设置保存


vim /etc/php.ini
改时区
date.timezone = Asia/Shanghai


5.1 打开浏览器输入服务器IP或本机配置也可输入127.0.0.1:8080



6.检查验证当前服务器是否安装中文包
locale -a | grep "zh_CN"

6.各个系统版本安装
##CentOS 8
dnf -y install glibc-langpack-zh.x86_64

##CentOS 7
yum groupinstall chinese-support -y

##Ubuntu
apt-get install language-pack-zh* -y


1.独立搭建监控平台，包括主机，路由器，交换机等
2.根据业务需求，自定义监控项，触发器