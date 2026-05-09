这是centos8系统
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



