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
