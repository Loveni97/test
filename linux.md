
## 管理逻辑卷
### 1.创建
#创建物理卷
1. pvcreate /dev/sda1 /dev/sda1 可以创建多个
#创建卷组
2. vgcreate vg01 /dev/sda1 /dev/sda1
默认4M PE大小
-s 16 指定16M大小
#创建逻辑卷
3. lvcreate -n lv01 -L 700M vg01
lvcreate -n lv01 -l 70 vg01
-l 70 指定70个PE
#格式化文件系统
4. mkfs -t xfs /dev/vg01/lv01
#挂载
5. /etc/fstab 
#删除逻辑卷
umount /mnt/data lvremove vgremove pvremove
#查看状态
pvdisplay
vgdisplay
lvdisplay

### 2.扩容
#扩展PV
pvcreate /dev/sda3
#扩展VG
vgextend vg01 /dev/sda3
#缩减VG
pvmove /dev/sda3先迁移数据
vgreduce vg01 /dev/sda3后移出卷组
#扩展lv
lvextend -L +300M /dev/vg01/lv01

#扩展文件系统xfs格式(扩展lv之后一定要记得！！！)
xfs_growfs /mnt/data
#扩展文件系统ext4格式(扩展lv之后一定要记得！！！)
resize2fs /mnt/data
#扩展文件系统swap格式(扩展lv之后一定要记得！！！)
mkswap /mnt/data

#对于ext4格式缩减容量
umount /dev/vg02/lv02
e2fsck -f /dev/vg02/lv02 #检查文件系统完整性
resize2fs /dev/vg02/lv02 1G#缩小到最小可能大小
lvreduce -L 1G /dev/vg02/lv02
mount -a

#对于vg删除某个pv,挪盘作用
首先确保lv空间在本vg组中满足（可以新增加pv到vg中）
pvremove /dev/nvme0n1p9
vgreduce vg02 /dev/nvme0n1p9
pvremove /dev/nvme0n1p9
以下是删除分区操作
fdisk /dev/nvme0n1#指定盘
d#删除
9#待删除分区号


## 高级存储管理stratis

yum install stratisd stratis-cli
systemctl enable stratisd --now

## docker
下载docker.repo
download.docker.com选择对应系统版本


sed -i s'#download.docker.com#mirrors.tuna.tsinghua.edu.cn/docker-ce#' /etc/yum.repos.d/docker-ce.repo 修改镜像
yum install -y docker-ce
配置共有仓库
/etc/docker/daemon.json

#常用命令
docker run 下载创建并运行
docker create 只创建
docker start 只运行

docker run -d --name 指定名字 -p 81:80(外部映射到内部) 镜像名
docker exec -it 镜像id /bin/bash #进入容器
docker cp /root/a 镜像名:/tmp/ cp到容器中
docker cp 镜像名:/tmp/aaa /root/ cp到宿主机中

文件挂载
-会覆盖容器中文件夹中内容
docker run -d --name 指定名字 -p 81:80(外部映射到内部) -v /root/:/usr/share/nginx/html/   镜像名 

docker rm `docker ps -aq` #批量删除容器

--restart=always#自动重启

日志查看

docker logs

只有做了软连接，外面才能看到

DockerFile
生成自定义镜像

FROM 基础镜像名nginx:alpine
LABEL author="glab"

COPY ./index.html /usr/share/nginx/html
EXPOSE 80 8080
CMD ["nginx","-g"，"daemon off;"]


docker build -t glab:v1 .   #.表示当前路径下的dockerfile文件


## podman
yum install container-tools.noarch

mkdir -p .config/containers
cp /etc/containers/registries.conf .config/containers/

podman login registry.lab.example.com
admin/redhat

podman search registry.lab.example.com/


## shell变量
四种执行脚本方式
bash
sh
.
source 脚本

普通变量
${}


环境变量

修改环境变量：

echo $PATH
echo $LANG
echo $HISTFILE
echo $HISTSIZE


export 临时生效，若永久需要改文件或者文件夹
/etc/profile  全局，函数，环境变量，别名
/etc/bashrc   全局，环境变量，别名
~/.bashrc     特定用户，局部，环境变量，别名
~/.bash_profile 特定用户
cd /etc/profile.d  登录有关

加载顺序
/etc/profile --> ~/.bash_profile --> ~/.bashrc  --> /etc/bashrc
             --> /etc/profile.d


env


特殊变量
1.位置变量
$N 第几个参数名
$# 脚本参数个数
$@ 所有参数  仅在双引号有区别
$* 所有参数


2.状态变量
$? 上一个命令执行结果。0表示成功，其他表示失败

$$当前脚本pid


计算

bc  小数计算  echo 1+1 | bc -l
awk 小数计算
expr 整数计算  expr 1 + 1  要有空格
let
$(())
$[]

-eq
-ne
-lt
-gt


-f
-x
-d
-w
-r

-e

1.判断



2.循环

for

do

done

3.数组


## ansible安装

yum whatprovides ansible 找到包名
yum install ansible-1:7.7.0-1.el9.noarch

1.免密

2.提权


1.加入wheel组
%wheel ALL=(ALL)  ALL
2.单独设一行
vim /etc/sudoers
sudo visudo
%devops ALL=(ALL)  ALL


ansible.cfg配置提权

[defatults]
inventory = ./inventory

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = false

## playbook
格式：
---
-name: test
 hosts: servera #主机组名
 tasks:
  - name: debug module for testing #task名
   ansible.built.debug: # 模块名
    var: result # result是变量名

### 管理变量
1.普通变量
三个地方定义:

    a.inventory(优先级最低)
    
    ---
    - name: test
      hosts: servera # 主机组名
      tasks:
        - name: debug module for testing # task名
          ansible.built.debug: # 模块名
            var: result # result是变量名

    在inventory中定义
    [servera]
    servera result=this is inventory vars

    使用：ansible-playbook vars.yml

    b.playbook(优先级最中)
    ---
    - name: test
      hosts: servera # 主机组名
      vars: 
        result: this is playbook vars # 这边直接赋值
      tasks:
        - name: debug module for testing # task名
          ansible.built.debug: # 模块名
            var: result # result是变量名

    使用：ansible-playbook vars.yml


    c.全局变量-e(优先级最高)

    ---
    - name: test
      hosts: servera # 主机组名
      tasks:
        - name: debug module for testing # task名
          ansible.builtin.debug: # 模块名
            var: result # result是变量名

    使用：ansible-playbook vars.yml -e "result=glab"




2.register变量

---
- name: test intranet web server
  hosts: localhost
  become: false
  tasks: 
    - name: connect to intranet web server
      ansible.builtin.url:
        url: http://servera.lab.example.com
        return_content: yes
        status_code: 200
      register: output # 这边是register变量
    - name: debug print output var
      ansible.builtin.debug:
        var: output   


3.事实变量fact变量------不需要定义

ansible servera -m setup # 获得servera上所有的事实变量

[devops@redhat-01 ansible]$ ansible ubuntu01 -m setup | grep mem
        "ansible_memfree_mb": 2413,
        "ansible_memory_mb": {
        "ansible_memtotal_mb": 3875,



- name: debug print output var
    ansible.builtin.debug:
    var: "{{ ansible_memfree_mb }}"   在playbook中使用fact变量格式


---
- name: test intranet web server
  hosts: localhost
  tasks: 
    - name: debug
      ansible.builtin.debug:
        var: ansible_facts   


ansible-navigator run -m stdout display_fact.yml # 容器运行方式

---
- name: test intranet web server
  hosts: localhost
  tasks: 
    - name: debug
      ansible.builtin.debug:
        msg: >
          Host "{{ ansible_facts["fqdn"] }}" with python  


## 循环和条件

1. loop-item形式
---
- name: firewalld and httpd are running
  hosts: ubuntu01
  tasks: 
    - name: running
      ansible.builtin.service:
        name: "{{ item }}"
        state: started
      loop:
        - firewalld
        - httpd
2. 字典列表


tasks: 
    - name: user
      user:
        name: "{{ item['name'] }}"
        state: present
        groups: "{{ item['groups'] }}"
      loop:
        - name: jane
          groups: wheel
        - name: joe
          groups: root
      
    


3.register+loop

---
- name: register and loop
  gather_facts: no
  hosts: ubuntu01

  tasks: 
    - name: looping echo task
      shell: "echo this is my item:{{ item }}"
      loop:
        - firewalld
        - httpd
      register: echo_results
    - name: show echo_results
      debug:
        var: echo_results

条件when
4.变量+loop

vars:
  mariadb_packages:
    - mariadb-server
    - python3-mysql
tasks:
  - name: install
    dnf:
      name: "{{ item }}"
      state: present
    loop: "{{ mariadb_packages }}"  
    when: ansible_facts['distribution'] == "RedHat"

  - name: start 
    service:
      name: maridba
      state: started
      enabled: true

ubuntu使用案例

vars:
  mariadb_packages:
    - apache2
    - mysql-server
tasks:
  - name: install
    apt:
      name: "{{ item }}"
      state: present
    loop: "{{ mariadb_packages }}"  
    when: ansible_facts['distribution'] == "ubuntu"

  - name: start apache2
    service:
      name: apache2
      state: started
      enabled: true

#service下面几种状态 started stopped restarted reloaded reloaded-or-restarted
#服务实际运行几种状态 active(running exited waiting) inactive failed unknown

#关于在debug中使用search
debug:
        msg: >
          服务{{ item.item }}的状态：{{ item.stdout_lines[2].split(':')[1] }}; mem: {{ (item.stdout_lines | select('search', 'Mem')) }}



## handler
---
- name: handler
  vars:
    packages:
      - nginx
      - php-fpm
    web_service: nginx
    app_service: php-fpm
    resources_dir: /home/user/ansible
    web_config_src: "{{ resources_dir }}/nginx.conf.standard"
    web_config_dest: /etc/nginx/nginx.conf
  hosts: ubuntu01

tasks:
  - name: "{{ packages }} are installed" # 所有包安装
    dnf:
      name: "{{ packages }} "
      state: present
  - name: make sure web service is running # 
    service:
      name: "{{ web_service }}"
      state: started
      enabled: true
  - name: make sure app service is running #   
    service:
      name: "{{ app_service }}"
      state: started
      enabled: true
  - name: make sure web config file has copied # copy文件
    copy:
      src: "{{ web_config_src }}"
      dest: "{{ web_config_dest }}"
      force: true
      notify:
        - restart_web_service

  - name: start apache2
    service:
      name: apache2
      state: started
      enabled: true

handlers:
  - name: restart_web_service
    service:
      name: "{{ web_service }}"
      state: restarted

## 错误处理
ignore_errors: yes 放在task下，跳过错误继续执行
force_handlers:  
failed_when: yes  执行成功标记为失败
  例如
  shell: /usr/create_users.sh
  register: command_result
  failed_when: "'Password missing' in command_result.stdout"

changed_when: 由于幂等性，但还是需要提醒
block-rescure-always
block-主要任务
rescure-主要任务失败则执行这个，否则不执行
always-最终都要执行


item.item
- stderr：标准错误输出（示例中为空字符串）；
- rc：命令执行返回码（0表示执行成功）；

- cmd：执行的具体命令（示例中为 ['systemctl', 'status', 'mysql']）；

- start：命令开始执行的时间戳；

- end：命令执行结束的时间戳；

- delta：命令执行耗时；

- msg：模块执行额外信息（示例中为空字符串）；

- invocation：模块调用参数详情（包含 _raw_params、_uses_shell 等子键）；

- stdout_lines：按行拆分后的标准输出列表；

- stderr_lines：按行拆分后的标准错误输出列表（示例中为空列表）；

- failed：命令执行是否失败（布尔值，示例中为 False）；

- item：当前循环的服务名称（示例中为 'mysql'）；

- ansible_loop_var：循环变量名称（固定为 'item'）



## jinja2模板

文件名*.j2


1.{# 这是注释 #}
2.{{ 变量 }}
3.{% 这是逻辑表达 %}
    条件，循环

this is  the system {{ ansible_facts['fqdn'] }}
this is a {{ ansible_facts['distribution'] version ansible_facts['distribution_version'] }} system
please report issues to {{ system_owner }}

tasks:
  - name: configure /etc/motd
    template:
      src: motd.j2
      dest: /etc/motd
      owner: root
      group: root
      mode: 0644


## import_tasks 和include_tasks

## 角色


创建角色
ansible-galaxy init glabhost

[devops@redhat-01 roles]$ tree glabhost/
glabhost/
├── defaults
│   └── main.yml
├── files
├── handlers
│   └── main.yml
├── meta
│   └── main.yml
├── README.md
├── tasks
│   └── main.yml
├── templates
├── tests
│   ├── inventory
│   └── test.yml
└── vars
    └── main.yml


角色入口 tasks/main.yml


角色仓库 galaxy.ansible.com



## 使用安装CC

1.安装
ansible-galaxy collection install 

2.ansible.cfg导入
ections
collections_paths =~/.ansible/collections:/usr/share/ansible/collections
 


## ansible故障处理
1.playbook本身
格式，键值对

--syntax-check
-vvvv

2.受管主机
1.python没配置
2.没有提权
3.免密
4.验证问题
5.错误inventory
6.变量定义错误


日常管理实例

管理软件
管理用户
计划任务
管理存储
管理网络



## 关于centos9 配置仓库
### 步骤 1：删除原有无效 repo 文件，新建清华源配置
1. 删除之前的阿里云源配置（避免冲突）
sudo rm -f /etc/yum.repos.d/CentOS-Stream-9.repo

2. 新建清华源 repo 文件
sudo vi /etc/yum.repos.d/CentOS-Stream-9-Tsinghua.repo

### 步骤 2：粘贴清华源配置（无需手动导入密钥，自动兼容）
[baseos]
name=CentOS Stream 9 - BaseOS (Tsinghua)
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-stream/9-stream/BaseOS/x86_64/os/
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/centos-stream/RPM-GPG-KEY-CentOS-Official
enabled=1
timeout=60

[appstream]
name=CentOS Stream 9 - AppStream (Tsinghua)
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-stream/9-stream/AppStream/x86_64/os/
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/centos-stream/RPM-GPG-KEY-CentOS-Official
enabled=1
timeout=60

[crb]
name=CentOS Stream 9 - CRB (Tsinghua)
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-stream/9-stream/CRB/x86_64/os/
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/centos-stream/RPM-GPG-KEY-CentOS-Official
enabled=1
timeout=60

[epel]
name=EPEL 9 - Extra Packages (Tsinghua)
baseurl=https://mirrors.tuna.tsinghua.edu.cn/epel/9/Everything/x86_64/
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/epel/RPM-GPG-KEY-EPEL-9
enabled=1
timeout=60

### 步骤 3：清理缓存 + 强制刷新（解决下载卡住问题）
1. 彻底清理旧缓存（包括无效连接缓存）
sudo dnf clean all && sudo rm -rf /var/cache/dnf/*

2. 关闭 IPv6（部分网络 IPv6 连接不稳定导致卡住）
echo "ip_resolve=4" | sudo tee -a /etc/dnf/dnf.conf

3. 强制生成新缓存（--refresh 强制重新拉取元数据）
sudo dnf makecache --refresh




## centos7yum安装

1. 修复 CentOS 7 Yum 源
创建修复脚本 fix_centos7_repo.sh

#!/bin/bash

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 用户运行"
    exit 1
fi

# 备份原有配置
mkdir -p /etc/yum.repos.d/backup
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/

# 创建新的 repo 配置
cat > /etc/yum.repos.d/CentOS-Base.repo << 'EOF'
[base]
name=CentOS-7 - Base
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/os/$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos-vault/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-7 - Updates
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/updates/$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos-vault/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-7 - Extras
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/extras/$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos-vault/RPM-GPG-KEY-CentOS-7
EOF

# 清理并重建缓存
yum clean all
yum makecache

echo "Yum 源修复完成！"

执行修复：
chmod +x fix_centos7_repo.sh
sudo ./fix_centos7_repo.sh

更新系统
sudo yum update -y

步骤 2：安装依赖包

sudo yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2

步骤 3：添加 Docker 官方 Yum 源
# 使用阿里云镜像（国内访问更快）
sudo yum-config-manager --add-repo \
    https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 修改为阿里云镜像地址
sudo sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' \
    /etc/yum.repos.d/docker-ce.repo


# 安装docker最新稳定版
sudo yum install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin


# 启动 Docker 服务
sudo systemctl start docker

# 设置开机自启
sudo systemctl enable docker

# 查看运行状态
sudo systemctl status docker


sudo systemctl daemon-reload
sudo systemctl restart docker



