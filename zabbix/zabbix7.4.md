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

dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent

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


4.3 配置Nginx

vim /etc/nginx/conf.d/zabbix.conf
#listen 8080;
#server_name example.com; 

#这两行取消注释并设置保存


vim /etc/php.ini
改时区
date.timezone = Asia/Shanghai


5.1 打开浏览器输入服务器IP或本机配置也可输入127.0.0.1:8080



6. 检查验证当前服务器是否安装中文包
locale -a | grep "zh_CN"

6. 各个系统版本安装
##CentOS 8
dnf -y install glibc-langpack-zh.x86_64

##CentOS 7
yum groupinstall chinese-support -y

##Ubuntu
apt-get install language-pack-zh* -y


# 监测交换机

## 1.进入 Vlanif1（默认管理VLAN）配置IP
interface Vlanif 1
 ip address 192.168.146.10 255.255.255.0
 quit

配置默认路由（如果需要访问外网，可选）
ip route-static 0.0.0.0 0.0.0.0 192.168.146.1

## 2.开启并配置 SNMP
### 开启SNMPv2c（最通用，Zabbix默认支持）
snmp-agent
snmp-agent community read public   # 只读团体字，默认public，建议修改
snmp-agent sys-info version all   # 支持所有SNMP版本

### 可选：配置SNMPv3（更安全，推荐）
snmp-agent group v3 admin privacy
snmp-agent usm-user v3 admin admin authentication-mode sha1 Admin@123 privacy-mode aes123 Admin@123


## 3.centos安装snmp
yum install net-snmp net-snmp-utils

### 3.1 修改团体字(交换机也需要同步改)
com2sec notConfigUser  default       public
com2sec notConfigUser  default       myzabbix

说明：default 表示允许所有 IP 访问，也可以限制为 Zabbix 服务器 IP，
例如：com2sec notConfigUser  192.168.146.100  myzabbix

交换机修改方式：

system-view
snmp-agent community read myzabbix

## 4.测试
修改为读取所有权限
view    systemview    included   .1
.1 代表 整个 SNMP 树全部放开，Zabbix 想拿什么指标都能拿到

华为自己的私有 OID 是：.1.3.6.1.4.1.2011

snmpwalk -v 2c -c public 192.168.146.10 .1.3.6.1.4.1.2011

## 测试CPU
for i in {1..6}; do while :; do :; done & sleep 3600; kill %$i; done


# 对于自动发现规则

## 1. 系统信息
zabbix_get -s 192.168.146.202 -k system.uname 
snmpwalk -v 2c -c public 192.168.146.10 sysDescr.0

接收到的值 包含 Linux 

# 钉钉报警
创建群，加入机器人
创建日志文件

## 1.写好脚本
将脚本写在/usr/lib/zabbix/alertscripts/目录下
[root@zabbix ~]# cd /usr/lib/zabbix/alertscripts/
 
##安装python或者python3
[root@zabbix alertscripts]# yum install python3 
pip3 requests json sys os datetime
 
[root@zabbix alertscripts]# vim dingding.py


在脚本文件夹
 




## 2.为脚本添加执行权限
[root@zabbix alertscripts]# chmod +x dingding.py
 
#修改脚本的属主和属组：
[root@zabbix alertscripts]# chown zabbix:zabbix dingding.py

[root@zabbix alertscripts]# mkdir -p /usr/lib/zabbix/log/
 
[root@zabbix alertscripts]# touch /usr/lib/zabbix/log/dingding.log
 
[root@zabbix alertscripts]# chown zabbix:zabbix -R /usr/lib/zabbix/log/



## 3. 测试
#py脚本 手机号 关键词 告警信息
./dingding.py 12312312312 告警 test
这边需要注意zabbix6.0这边页面测试需要将参数改为 3 1 2 ,这样才能对应


## 添加动作
配置–>动作–>创建动作


#告警操作内容：

##标题：
服务器:{HOST.NAME}发生: {TRIGGER.NAME}故障!

##消息内容：
告警主机:{HOST.NAME}
告警地址:{HOST.IP}
监控项目:{ITEM.NAME}
监控取值:{ITEM.LASTVALUE}
告警等级:{TRIGGER.SEVERITY}
当前状态:{TRIGGER.STATUS}
告警信息:{TRIGGER.NAME}
告警时间:{EVENT.DATE} {EVENT.TIME}
事件ID:{EVENT.ID}
 
 
#恢复操作内容
##标题：
服务器:{HOST.NAME}: {TRIGGER.NAME}已恢复!
##消息内容：
告警主机:{HOST.NAME}
告警地址:{HOST.IP}
监控项目:{ITEM.NAME}
监控取值:{ITEM.LASTVALUE}
告警等级:{TRIGGER.SEVERITY}
当前状态:{TRIGGER.STATUS}
告警信息:{TRIGGER.NAME}
告警时间:{EVENT.DATE} {EVENT.TIME}
恢复时间:{EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}
持续时间:{EVENT.AGE}
事件ID:{EVENT.ID}



Resolved in {EVENT.DURATION}: {EVENT.NAME}



Problem has been resolved at {EVENT.RECOVERY.TIME} on {EVENT.RECOVERY.DATE}
Problem name: {EVENT.NAME}
Problem duration: {EVENT.DURATION}
Host: {HOST.NAME}
Severity: {EVENT.SEVERITY}
Original problem ID: {EVENT.ID}
{TRIGGER.URL}



# 远程登录交换机

## ssh方式-由于交换机ssh加密算法版本太低，可能导致登录失败

### 配置本地用户
[sw02] aaa
[sw02-aaa] local-user admin password simple Huawei@123
[sw02-aaa] local-user admin privilege level 15
[sw02-aaa] local-user admin service-type ssh
[sw02-aaa] quit

### 配置SSH
[sw02] stelnet server enable
[sw02] ssh user admin authentication-type password

### 配置VTY
[sw02] user-interface vty 0 4
[sw02-ui-vty0-4] authentication-mode aaa
[sw02-ui-vty0-4] protocol inbound ssh
[sw02-ui-vty0-4] quit

## telnet方式
telnet server enable
user-interface vty 0 4
 authentication-mode password
 set authentication password simple admin123
 user privilege level 15
 protocol inbound telnet
quit


登录方式telnet 192.168.146.10

# 知识技能

1.独立搭建监控平台，包括主机，路由器，交换机等
2.根据业务需求，自定义监控项，触发器，数据可视化
3.数据可视化‌：提供折线图、柱状图、饼图、拓扑图、地图等多种可视化形式
4.实现邮件、短信、钉钉、微信等多种通知方式，并可配置告警升级策略


# 遇到的问题：
1.zabbix_get 命令行测试和网页能读到数据，但监测显示没有数据
解决方法：其实是主机ip给错了