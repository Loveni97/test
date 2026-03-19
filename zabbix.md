安装zabbix的repo
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
rpm -ivh https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm

rpm -ivh https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/4.0/rhel/8/x86_64/zabbix-release-4.0-2.el8.noarch.rpm

替换镜像
sed -i 's#repo.zabbix.com#mirrors.tuna.tsinghua.edu.cn/zabbix#g' /etc/yum.repos.d/zabbix.repo

安装
yum install -y zabbix-server-mysql zabbix-web-mysql zabbix-agent mariadb-server

  
启动mysql并设置开机自启
systemctl start mariadb && systemctl enable mariadb


3.设置mariadb数据库，创建zabbix库，存储监控数据，且创建账号
mysqladmin password linux0224
mysql -uroot -plinux0224 -e 'create database zabbix character set utf8 collate utf8_bin;'
mysql -uroot -plinux0224 -e 'show databases;'

创建用户账户，zabbix 密码是linux0224
给与权限是，zabbix这个用户，对于zabbix这个库下的所有表，都是最大权限
mysql -uroot -plinux0224 -e "grant all privileges on zabbix.* to zabbix@localhost identified by 'linux0224';"


4.导入服务端数据库
zcat /usr/share/doc/zabbix-server-mysql/create.sql.gz | mysql -uroot -plinux0224 zabbix

zcat /usr/share/doc/zabbix-server-mysql-4.0.50/create.sql.gz | mysql -uroot -plinux0224 zabbix

mysql -uroot -plinux0224 -e 'show tables from zabbix;'


5.修改服务端配置文件
grep "^[a-Z]" /etc/zabbix/zabbix_server.conf

LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=e
PidFile=/var/run/zabbix/zabbix_server.pid
SocketDir=/var/run/zabbix
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=linux0224
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=4
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts
LogSlowQueries=3000

cat > /etc/zabbix/zabbix_server.conf <<'EOF'

LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
PidFile=/var/run/zabbix/zabbix_server.pid
SocketDir=/var/run/zabbix

DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=linux0224
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=4
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts
LogSlowQueries=3000
EOF

6.启动服务端程序并开机自启
setenforce 0
systemctl start zabbix-server && systemctl enable zabbix-server

7.检查服务端是否运行
netstat -tulnp | grep zabbix



apache配置


vim /etc/httpd/conf.d/zabbix.conf


vim /etc/php-fpm.d/zabbix.conf
systemctl start httpd
systemctl restart php-fpm

<IfModule mod_php5.c>
    php_value max_execution_time 300
    php_value memory_limit 128M
    php_value post_max_size 16M
    php_value upload_max_filesize 2M
    php_value max_input_time 300
    php_value max_input_vars 10000
    php_value always_populate_raw_post_data -1
    php_value date.timezone Asia/Shanghai
</IfModule>




访问:192.168.88.130/zabbix

默认密码
Admin
zabbix


修改页面乱码情况

#文泉仪微黑字体
[root@zabbix4-server ~]#yum install wqy-microhei-fonts -y

#拷贝字体给zabbix用，覆盖图形字体
[root@zabbix4-server ~]#cp /usr/share/fonts/wqy-microhei/wqy-microhei.ttc /usr/share/zabbix/assets/fonts/graphfont.ttf

几个核心概念


1.主机，linux,win或者网络设备
2.模板，一类监控对象的抽象，比如win模板
3.监控项，定义具体某一项的监控指标，系统自带的，自定义
4.触发器，基于监控项存在的， 
5.动作，基于触发器存在的

监控自己


ntpdate -u ntp1.aliyun.com

这是系统8
rpm -ivh https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/4.0/rhel/8/x86_64/zabbix-agent-4.0.11-1.el8.x86_64.rpm

这是系统9
rpm -ivh https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/4.0/rhel/9/x86_64/zabbix-agent-4.0.46-2.el9.x86_64.rpm

rpm -qa zabbix-agent


vim /etc/zabbix/zabbix_agentd.conf 修改配置
dG全部删除，不能有中文，修改serverip

cat > /etc/zabbix/zabbix_agentd.conf << 'EOF'
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=192.168.88.130
Include=/etc/zabbix/zabbix_agentd.d/*.conf
EOF


systemctl start zabbix-agent && systemctl enable zabbix-agent

在接口中写明ip地址
![alt text](image.png)

systemctl restart zabbix.agent

netstat -tnlup | grep zabbix_agent


3.5安装zabbix-get命令，检测是否通信了

yum install -y zabbix-get


1.看日志
cat 
2. zabbix_get -s 192.168.88.134 -k agent.ping


自定义模板



自定义监控项



完全流程
1.写命令、脚本
2.编写zabbix的自定义监控项的配置文件
3.重启zabbix-agent
4.试试zabbix-get能拿到数据吗
5.去zabbix-ui 添加监控项


案例：tcp的11个连接状态


cat >/etc/zabbix/zabbix_agentd.d/tcp_status.conf <<'EOF'
UserParameter=LISTEN,netstat -ant grep -c LISTEN
UserParameter=TIME_WAIT,netstat -ant grep -c TIME_WAIT
UserParameter=ESTABLISHED,netstat -ant grep -c ESTABLISHED
EOF