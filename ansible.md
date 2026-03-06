# 一、文件管理
1.安装软件
ansible all -m dnf -a "name=nginx state=present" 安装
ansible all -m dnf -a "name=nginx state=absent" 卸载
ansible all -m dnf -a "name=nginx state=latest" 更新
ansible all -m dnf -a "name=* state=latest" 更新所有包

2.创建删除文件/文件夹
touch= 创建文件、directory= 创建目录、absent= 删除文件 / 目录
mode：可选，指定文件 / 目录权限（如 0644 是文件默认、0755 是目录默认）
owner/group：可选，指定文件 / 目录的属主 / 属组（默认 root）

ansible all -m file -a "path=/tmp/test.txt state=touch mode=0644 owner=devops group=devops"
ansible all -m file -a "path=/tmp/test.txt state=absent"

ansible all -m file -a "path=/tmp/data state=directory mode=0755 owner=devops group=devops" # 支持多级
ansible all -m file -a "path=/tmp/data state=absent"

3.创建目录-playbook写法：
- name: 创建多级目录 /opt/app/nginx
  ansible.builtin.file:
    path: /opt/app/nginx
    state: directory
    mode: 0755  # 目录默认755，保证用户可进入、读目录
    recurse: yes  # 可选：递归设置子目录权限（若已有子目录，同步修改权限）

4.创建同时写入文件
---
- name: 创建 /etc/test.conf 并写入静态内容
  hosts: all
  tasks:
    - name: create
      copy:
        content: |
          port=80
          host=0.0.0.0
          log_path=/var/log/test.log
        dest: /tmp/test.conf  # 远程节点文件路径（不存在则创建，存在则覆盖）
        mode: 0644
        owner: root

5.本地拷贝文件copy
ansible all -m copy -a "src=/tmp/local.txt dest=/tmp/remote.txt mode=0644"

#Playbook写法
- name: 分发本地文件到远程节点
  ansible.builtin.copy:
    src: /tmp/local.txt  # 控制节点本地文件路径
    dest: /tmp/remote.txt  # 远程节点目标路径
    mode: 0644

# 二、用户管理
1.创建用户
1.1 ansible all -m user -a "name=testuser shell=/bin/bash create_home=yes"

2.设置密码
echo "123" | openssl passwd -6 -stdin  # -6表示SHA512加密（主流Linux推荐）

编辑ansible文件
- name: 为testuser设置加密密码
  hosts: all
  tasks:
    - name: 修改用户密码
      ansible.builtin.user:
        name: testuser
        password: "$6$xxxxxxxxx$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # 替换为步骤1生成的加密串
        update_password: always  # 每次执行都更新密码（默认on_create，仅创建时设置）


创建单个用户示例（playbook写法）
- name: 创建系统用户
  hosts: all
  tasks:
    - name: 创建用户testuser，指定UID、家目录和shell
      ansible.builtin.user:
        name: testuser          # 用户名（必选）
        uid: 10086              # 指定UID，避免自动分配冲突
        home: /home/testuser    # 家目录路径
        shell: /bin/bash        # 登录shell（默认/bin/bash）
        create_home: yes        # 自动创建家目录（默认yes）
        state: present          # 确保用户存在（默认present）
        system: no              # 是否为系统用户（默认no，系统用户UID通常<1000）

3.添加用户到指定组（主组 / 附加组） 

usermod -aG wheel testuser

- name: 配置用户所属组
  hosts: all
  tasks:
    - name: 将testuser加入主组dev，附加组wheel、docker
      ansible.builtin.user:
        name: testuser
        group: dev               # 主组（默认创建同名组）
        groups: wheel,docker     # 附加组（多个用逗号分隔）
        append: yes              # 追加组（默认no，会覆盖原有附加组！必加yes避免丢失）

4.免密登录

- name: 配置testuser的SSH免密登录
  hosts: all
  tasks:
    - name: 推送公钥到testuser的authorized_keys
      authorized_key:
        user: testuser                          # 目标用户
        state: present                          # 确保密钥存在
        key: "{{ lookup('file', '/home/devops/.ssh/id_rsa.pub') }}"  # 本地公钥路径
        path: /home/testuser/.ssh/authorized_keys  # 目标密钥文件（默认自动生成）
        manage_dir: yes                         # 自动创建~/.ssh目录并设置权限（默认yes）
    - name: Set permissions on the authorized_keys file
      ansible.builtin.file:
        path: /home/testuser/.ssh/authorized_keys  # 目标密钥文件（默认自动生成）
        mode: '0600'


5.批量管理多个用户（循环方式）
- name: 批量创建用户
  hosts: all
  tasks:
    - name: 批量创建dev组下的多个用户
      ansible.builtin.user:
        name: "{{ item.name }}"
        uid: "{{ item.uid }}"
        group: dev
        shell: /bin/bash
        create_home: yes
      loop:                     # 循环列表，批量处理
        - { name: user1, uid: 10087 }
        - { name: user2, uid: 10088 }
        - { name: user3, uid: 10089 }



# ansible-galaxy
ansible-galaxy search'redis' --platforms EL #查找EL平台下的redis
ansible-galaxy info geerlingguy.redis # 以下命令显示了Ansible Galaxy提供的geerlingguy.redis角色的相关信息。
ansible-galaxy install -r ./roles/requirements.yml #安装角色
ansible-galaxy list  #列出本地角色。
ansible-galaxy remove nginx  #删除本地nginx角色。




在ansible.cfg的[defaults]下追加
[defaults]
inventory = /home/devops/ansible/inventory
roles_path = /home/devops/ansible/roles
log_path = /home/student/troubleshoot-playbook/ansible. log # 配置日志文件路径
这样安装包下载后就在这个文件夹下

在roles_path下编辑requirements.yml
执行ansible-galaxy install -r ./roles/requirements.yml 进行角色安装

requirements.yml格式
- src: geerlingguy.redis
  version: "1.5.0" #指定版本
  scm: git #如果角色托管在来源控制存储库中，则需要使用scm属性。如果角色托管在Ansible Galaxy中，或者以tar存档形式托管，则省略scm关键字。
  name: myrole #关键字用于覆盖角色的本地名称

## collections
ansible-galaxy collection install -r collections/requirements.yml



# 所有常用模块
## dnf
- name: install package
  dnf:
    name:    #'*'
      - httpd  
      - firewalld  
    state: present #absent latest(dnf upgrade)
    enabled: true
#如果用loop，效率低，需要单独循环执行任务
- name: install package
  dnf:
    name: "{{ item }}"  
    state: present #absent latest(dnf upgrade)
    enabled: true
  loop:
    - httpd  
    - firewalld  



dnf group list/install/info
dnf module list/install/info


## user

- name: create user
  user:
    name: devops2
    shell: /bin/bash
    groups: wheel
    append: true
    state: absent
    home: ""
    create_home: true
    state: present 创建 absent 删除
    generate_ssh_key: true
    ssh_key _bits: 2048 #密钥位数
    ssh_key_file: .ssh/id_my_rsa

## group
groupadd groupdel groupmod

- name: create group
  group:
    name: auditors
    state: present

## known_hosts

## ansible.posix.authorized_key #添加密钥

- name: Set authorized key
  ansible.posix.authorized_key:
    user: user1 #受管主机用户名
    state: present
    key: "{{ lookup('ansible.builtin.file','files/user1/id_rsa.pub') }}" #查找ansible文件夹下文件

## ansible.builtin.lineinfile #添加sudo权限
- name: Modify sudo to allow the groupe1 group sudo without a password
  ansible.builtin.lineinfile:
    path: /etc/sudoers.d/user2
    state: present
    create: true
    mode: 0440
    line: "%user2 ALL=(ALL) NOPASSWD: ALL"
    validate: /usr/sbin/visudo -cf %s


- name: disabled root login
  ansible.builtin.lineinfile:
    dest: /etc/ssh/sshd_config
    regexp: "^PermitRootLogin"
    line: "PermitRootLogin no"
    notify: Restart sshd


## 综合案例
---
- name: create users
  hosts: centos8
  vars_files:
    - vars/users_vars.yml
  tasks:
    - name: create group
      group:
        name: webadmin
        state: present
    - name: create user
      user:
        name: "{{ item['username'] }}"
        groups: "{{ item['groups'] }}"
      loop: "{{ users }}"
    - name: add keys
      ansible.posix.authorized_key:
        user: "{{ item['username'] }}"
        key: "{{ lookup('file', 'files/'+ item['username'] + '.key.pub')}}"
      loop: "{{ users }}"
    - name: Modify sudo to allow the groupe1 group sudo without a password
      ansible.builtin.lineinfile:
        path: /etc/sudoers.d/webadmin
        state: present
        create: true
        mode: 0440
        line: "%webadmin ALL=(ALL) NOPASSWD: ALL"
        validate: /usr/sbin/visudo -cf %s
    - name: disabled root login
      ansible.builtin.lineinfile:
        dest: /etc/ssh/sshd_config
        regexp: "^PermitRootLogin"
        line: "PermitRootLogin no"
      notify: Restart sshd
  handlers:
    - name: Restart sshd
      service:
        name: sshd
        state: restarted
