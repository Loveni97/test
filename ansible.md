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

 
