## 配置k8s

#关闭防火墙
systemctl stop firewalld 
systemctl disable firewalld

#关闭selinux
sed -i 's/enforcing/disabled/' /etc/selinux/config #永久
setenforce 0  #临时
#关闭swap
swapoff -a #临时
sed -ri 's/.*swap.*/#&/'  /etc/fstab # 永久

#关闭完swap后，一定要重启虚拟机!!!

cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

命令生效
sysctl --system

## 时间同步
yum install ntpdate -y
ntpdate time.windows.com
ntpdate ntp1.aliyun.com

## k8s仓库
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF


yum install -y kubelet-1.23.6 kubeadm-1.23.6 kubectl-1.23.6
systemctl enable kubelet

## 部署master
kubeadm init \
 --apiserver-advertise-address=192.168.146.134 \
 --image-repository registry.aliyuncs.com/google_containers \
 --kubernetes-version v1.23.6 \
 --service-cidr=10.96.0.0/12 \
 --pod-network-cidr=10.244.0.0/16

 所有节点都需要修改，修改daemon.json驱动配置
 "exec-opts": ["native.cgroupdriver=systemd"]

 systemctl daemon-reload
 systemctl restart docker
 systemctl restart kubelet

 cubeadm reset 重置后再执行初始化

 mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


## 加入node

#下方命令可以在 k8s master 控制台初始化成功后复制 join 命令
kubeadm join 192.168.146.134:6443 --token <master控制台的token>
--discovery-token-ca-cert-hash <master控制台的hash>

如果token过期
kubeadm token create
没有过期，则通过下面命令获取
kubeadm token list

关于hash获取命令
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
openssl dgst -sha256 -hex | sed 's/^.* //'

需要sha256:拼接
sha256:f416e13878a1b6aaeec63e24c746d9fcfd43bb5e84ece1d9346691eaef21b42e

kubeadm join 192.168.146.134:6443 --token nkiphw.ksczf1yd65jpkgzj --discovery-token-ca-cert-hash sha256:f416e13878a1b6aaeec63e24c746d9fcfd43bb5e84ece1d9346691eaef21b42e

kubectl get cs
kubectl get pods -n kube-system


这边是针对master作修改
1.
curl https://calico-v3-25.netlify.app/archive/v3.25/manifests/calico.yaml -O
修改CALICO_IPV4POOL_CIDR配置--pod-network-cidr=10.244.0.0/16
2.添加 IP_AUTODETECTION_METHOD
- name: IP_AUTODETECTION_METHOD
  value: "interface=ens.*"  # ens 根据实际网卡开头配置，支持正则表达式
"interface=ens33"
sed -i 's#docker.io/##g' calico.yaml

kubectl apply -f calico.yaml


## 测试集群
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get pod,svc


##  其他node如何使用kubectl
1.将master节点中/etc/kubernetes/admin.conf 拷贝到其他node/etc/kubernetes中
scp /etc/kubernetes/admin.conf root@k8s-node1:/etc/kubernetes/
2.配置环境变量
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >>~/.bash_profile
source ~/.bash_profile


po deploy svc nodes ns 五种资源

kubectl get deploy 获取deploy名字
kubectl scale deploy --replicas=3 nginx

kubectl delete deploy nginx
kubectl delete svc nginx

kubectl get po -o wide
kubectl get pod --show-labels
# 检查Calico网络是否正常
kubectl get pod -n kube-system | grep calico-node

kubectl create -f nginx-demo.yaml

# ========== Deployment 常用命令 ==========
kubectl get deploy          # 查看所有Deployment
kubectl describe deploy 名称 # 查看Deployment详情
kubectl apply -f deploy.yaml # 创建Deployment
kubectl scale deploy 名称 --replicas=3 # 扩容/缩容
kubectl rollout restart deploy 名称 # 重启Deployment
kubectl delete deploy 名称   # 删除Deployment

kubectl get deploy 名称 -o yaml #输出配置文件

kubectl edit deploy nginx-deploy #编辑deploy
kubectl rollout history deploy nginx-deploy #查看回滚历史
kubectl rollout history deploy nginx-deploy --revision=2 #查看回滚历史的版本2的详细信息
kubectl rollout undo deploy nginx-deploy --to-vision=2 #回退到指定2版本

kubectl rollout pause deploy nginx-deploy --to-vision=2 #暂停更新
kubectl rollout resume deploy nginx-deploy --to-vision=2 #恢复更新

# ========== Service 常用命令 ==========
kubectl get svc             # 查看所有Service
kubectl describe svc 名称    # 查看Service详情
kubectl apply -f svc.yaml    # 创建Service
kubectl delete svc 名称      # 删除Service

# ========== 联动查询 ==========
kubectl get pod -l app=nginx # 查看指定标签的Pod
kubectl get deploy,svc       # 同时查看Deployment和Service

# ========== pod操作 ==========
kubectl get pod --show-labels
kubectl get pod -l 'version in (1.0.0,1.0.1),author=zrn'
kubectl label pod pod资源名称 author=zrn #添加资源名
kubectl label pod pod资源名称 author=zrn --overwrite #重命名资源名

# ========== statefulset操作 ==========
kubectl run -it --image busybox:1.28.4 dns-test /bin/sh # 为了测试集群中服务的网络

kubectl edit sts 名字
kubectl scale sts 名字 --replicas=2

金丝雀部署
修改partition字段 >=num的pod进行更新

updateStrategy:
  rollingUpdate:
    partition: 0
  type: RollingUpdate

另一种更新策略
updateStrategy:
  type: OnDelete 只有删除pod的时候才更新，然后创建并更新

关于sts的删除，因为是有状态的
默认是删除pod
kubelctl delete sts web --cascade=false #关闭级联

kubelctl delete svc 
kubelctl delete pvc # 持久化存储


## daemonset
首先创建ds配置文件--fluent-ds.yaml 

kubelctl edit ds fluentd

apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  selector:
    matchLabels:
      app: logging
  template:
    metadata:
      labels:
        app: logging
        id: fluentd
      name: fluentd
    spec:
      nodeSelector:
        type: microservices  # 这边添加node选择标签
      containers:
      - name: fluentd-es
        image: agilestacks/fluentd-elasticsearch:v1.3.0
        env:
         - name: FLUENTD_ARGS
           value: -qq
        volumeMounts:
         - name: containers
           mountPath: /var/lib/docker/containers
         - name: varlog
           mountPath: /varlog
      volumes:
        - hostPath:
            path: /var/lib/docker/containers
            name: containers
        - hostPath:
            path: /var/log
            name: varlog

kubelctl label node centos7-03 type=microservices #为节点添加标签，那么服务自动添加

## HPA自动扩容缩容


kubectl autoscale deploy nginx-deploy --cpu-percent=20 --min=2 --max=5

1.
yum install -y wget
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -O metric-server-components.yaml
2.
然后修改仓库
sed -i 's/k8s.gcr.io\/metrics-server/registry.cn-hangzhou.aliyuncs.com\/google_containers/g' metric-server-components.yaml
其实就是修改这两处
 - --kubelet-insecure-tls
 image: registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server:v0.8.0
        registry.aliyuncs.com/google_containers/metrics-server:v0.6.4

kubectl apply -f metric-server-components.yaml


创建一个nginx-svc.yaml

apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  labels:
    app: nginx
spec:
  selector:
    app: nginx-deploy
  ports:
  - port: 80
    targetPort: 80
    name: web
  type: NodePort



kubectl get svc -o wide
while true; do wget -q -O- http://10.96.53.140 > /dev/null ; done


## service外部访问其他网站-ip代理

1.配置service -nginx-svc-external.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc-external
  labels:
    app: nginx
spec:# 不需要selector
  ports:
  - port: 80
    targetPort: 80
    name: web
  type: ClusterIP

2.配置endpoint -nginx-np-external.yaml

apiVersion: v1
kind: Endpoints
metadata:
  name: nginx-svc-external
  labels:
    app: nginx
  namespace: default
subsets:
- addresses:
  - ip: 120.78.159.117 # 外部服务ip
  ports:
  - name: web
    port: 80
    protocol: TCP

## service外部访问其他网站-域名代理

1.配置service -nginx-svc-externalname.yaml
apiVersion: v1
kind: Service
metadata:
  name: wolfcode-external-domain
  labels:
    app: wolfcode-external-domain
spec:
  type: ExternalName
  externalName: www.wolfcode.cn


## ingress安装

wget https://get.helm.sh/helm-v3.2.3-linux-amd64.tar.gz

移动到/usr/local/bin

添加helm仓库
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm search repo ingress-nginx

helm pull ingress-nginx/ingress-nginx --version=4.4.2

tar -xf 

vim values.yaml
chroot: false
registry: registry.cn-hangzhou.aliyuncs.com
image: google_containers/nginx-ingress-controller
注释两个校验digest
修改tag: v1.5.1

webhook处也要修改
registry: registry.cn-hangzhou.aliyuncs.com
image: google_containers/kube-webhook-certgen
同样注释digest
修改tag: v1.5.1

修改部署配置的 kind: DaemonSet
nodeSelector:
  ingress: "true"#增加选择器，如果 node 上有ingress=true 就部署

修改
hostNetwork: true
dnsPolicy: ClusterFirstWithHostNet

修改service中
type: ClusterIP

单独创建命名空间
kubectl create ns ingress-nginx

# 为需要部署 ingress 的节点上加标签 - 避免在master
kubectl label node k8s-master ingress=true
kubectl label node k8s-node1 ingress=true 
# 安装ingress-nginx-需要在values.yaml路径下
helm install ingress-nginx -n ingress-nginx .

修改
Webhooks :
admissionannotations:
  enabled: false


# 方案一：轻量强制删除（优先）
kubectl delete ns 命名空间名 --force --grace-period=0

# 方案二：导出ns配置
kubectl get ns 命名空间名 -o json > ns-terminating.json

# 开启API代理
kubectl proxy

# 终极删除命令
curl -k -H "Content-Type: application/json" -X PUT --data-binary @ns-terminating.json http://127.0.0.1:8001/api/v1/namespaces/命名空间名/finalize

# 清理残留Pod
kubectl delete pod --all -n 命名空间名 --force --grace-period=0


# 使用ingress案例  wolfcode-ingress.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wolfcode-nginx-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: k8s.wolfcode.cn
    http:
      paths:
      - pathType: Prefix
        backend:
          service:
            name: nginx-svc
            port:
              number: 80
        path: /so

在本地host配置
192.168.146.135 k8s.wolfcode.cn  其中ip通过kubectl get ingress -o wide 得到节点
必须通过域名访问，否则无效！！！ 

## 创建configmap
kubectl create cm 配置名 --from-file=路径
kubectl create cm 配置名 --from-file=key1=文件1 --from-file=key2=文件2 #修改配置文件名
kubectl create cm 配置名 --from-file=文件1 --from-file=文件2 #默认不修改
kubectl create cm 配置名 --from-literal=username=admin

## 使用configmap

env:
- name: JAVA_VM_OPTS
    valueFrom:
      configMapKeyRef:
        name:test-env-config # configMap 的名字
        key: JAVA_OPTS_TEST # 表示从 name 的 ConfigMap 中获取名字为 key 的 value，将其赋值给本地环境变量 JAVA VM OPTS
- name: APP
    valueFrom:
      configMapKeyRef:
        name: test-env-config
        key: APP_NAME


# 有多个配置文件，可以指定
spec:
  containers:
    -name: config-test
      image: alpine
      command:["/bin/sh","-c","sleep 3600"]
      imagePullPolicy: IfNotPresent
      env:
      - name: JAVA_VM_OPTS
        valueFrom:
          configMapKeyRef:
            name: test-env-config
            key: JAVA_OPTS_TEST
      - name: APP
        valueFrom:
          configMapKeyRef:
            name: test-erv-config
            key: APP_NAME
      volumeMounts:#加载数据卷
        - name: db-config # 表示加载属性中哪个数据卷
          volumesmountPath:"/usr/local/mysql/conf" # 想要将数据卷中的文件加载到哪个目录下
          readOnly:true # 是否只读
    volumes:#数据卷挂载 configmap、secret·name:db-config # 数据卷的名字，随意设置
      configMap: # 数据卷类型为 CofngiMap
      name: test-dir-config # configMap 的名字，必须跟想要加载的 configmap 相同中的 key 进行映射，如果不指定，默认会讲 configmap 中所有 key 全部转换为一个个同名的文件
      items: #对configmap
        - key: "db.properties" # configMap 中的key
          path: db.properties # 将该 key 的值转换为文件
  restartPolicy: Never


## 创建secret

kubectl create secret generic 名字 --from-literal=username=admin
kubectl create secret docker-registry 名字 --docker-username=admin --docker-password=admin --docker-email=admin

## SubPath使用

## 配置的热更新
方式1.通过edit直接修改configmap

方式2.
kubectl create cm cm名称 --from-file=./test/ --dry-run -o yaml | kubectl replace -f


## 不可变的secret和configmap
编辑configmap文件
kubectl edit cm test-dir-config(cm文件名)
加参数 immutable: true

## 存储管理

1.hostPath

vim volume-test-pd.yaml

apiVersion: v1
kind: Pod
metadata:
  name: test-volume-pd
spec:
  containers:
  - image: nginx
    name: nginx-volume
    volumeMounts:
    - mountPath: /test-pd # 挂载到容器的哪个目录
      name: test-volume #挂载哪个volume
  volumes :
    - name: test-volume
      hostPath:
        path: /data # 节点中的目录
        type: Directory # 检査类型，在挂载前对挂载目录做什么检査操作，有多种选项，默认为空字符串，不做任何检査

type: 1.DirectoryOrCreate  如果不存在则创建
2.Directory  
3.File


2.EmptyDir # 一个pod中多个容器共享同一个数据卷，仅在pod中使用，没有持久化能力，如果pod删除则都删除了





vim empty-dir-pd.yaml

apiVersion: v1
kind: Pod
metadata:
  name: empty-dir-pd
spec:
  containers:
  - image: alpine
    name: nginx-emptydir1
    command: ["/bin/bash", "-c", "sleep 3600;"]
    volumeMounts:
    - mountPath: /cache # 第一个容器挂在目录
      name: cache-volume #挂载哪个volume
  - image: alpine
    name: nginx-emptydir2
    command: ["/bin/bash", "-c", "sleep 3600;"]
    volumeMounts:
    - mountPath: /opt # 第二个容器挂在目录
      name: cache-volume #挂载哪个volume
  volumes :
    - name: cache-volume
      emptyDir: {}


kubectl create -f empty-dir-pd.yaml

kubectl exec -it empty-dir-pd -c nginx-emptydir1 --sh #进入容器1
kubectl exec -it empty-dir-pd -c nginx-emptydir2 --sh #进入容器2

在其中一个容器中挂载的目录下编辑文件，在另一个容器挂载的目录下可以看到文件更新

## nfs服务
每个node都需要安装
# 安装 nfs 
yum install nfs-utils -y
# 启动 nfs 
systemctl start nfs-server
# 查看 nfs 版本
cat /procfs/nfsd/version
# 创建共享目录 
mkdir -p /home/nfs
cd nfs
mkdir ro rw 创建两个文件夹 



# 设置共享目录 export
vim /etc/exports

/home/nfs/rw 192.168.146.0/24(rw,sync,no_subtree_check,no_root_squash)
/home/nfs/ro 192.168.146.0/24(ro,sync,no_subtree_check,no_root_squash)
# 重新加载
exportfs -f
systemctl reload nfs-server

然后在其他node执行挂载

mkdir -p /mnt/nfs/rw
mkdir -p /mnt/nfs/ro
mount -t  nfs 共享服务的ip(192.168.146.135):/home/nfs/rw 本地文件路径(/mnt/nfs/rw)
mount -t  nfs 共享服务的ip(192.168.146.135):/home/nfs/ro 本地文件路径(/mnt/nfs/ro)

## 将nfs挂载到pod
vim nfs-test-pd1.yaml

apiVersion: v1
kind: Pod
metadata:
  name: nfs-test-pd1
spec:
  containers:
  - image: nginx
    imagePullPolicy: IfNotPresent
    name: test-container
    volumeMounts :
    - mountPath: /usr/share/nginx/html
      name: test-volume
  volumes:
  - name: test-volume
    nfs:
      server: 192.168.146.135 # 网络存储服务地址
      path: /home/nfs/rw/www/wolfcode # 网络存储路径,需要创建好
      readOnly: false # 是否只读


kubectl create -f nfs-test-pd.yaml
kubectl get po -o wide 获取ip
/home/nfs/rw/www/wolfcode 路径下新建index.html文件
curl ip 得到html结果


## pv和pvc
步骤一
vim pv-nfs.yaml

apiVersion: v1
kind: PersistentVolume 
metadata:
  name: pv0001
spec:
  capacity:
    storage: 5Gi # pv 的容量
  volumeMode: Filesystem # 存储类型为文件系统
  accessModes: # 访问模式:ReadWriteOnce、 ReadwriteMany、 ReadonlyMany
    - ReadWriteOnce #可被单节点独写
  persistentVolumeReclaimPolicy: Recycle # 回收策略,retain,delete
  storageclassName: slow # 创建 PV 的存储类名，需要与 pvc 的相同
  mountOptions:#加载配置
    - hard
    - nfsvers=4.1
  nfs: # 连接到 nfs
    path: /home/nfs/rw/test-pv # 存储路径
    server: 192.168.146.135 # 提供 nfs 的IP

kubectl create -f pv-nfs.yaml
kubectl get pv

状态：
available: 未绑定状态
bound: 已经绑定
released: pv未被重新使用

步骤二
vim pvc-test.yaml

apiVersion: v1
kind: PersistentVolumeClaim # 资源类型为PVC
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce # 权限需要与对应的 pv 相同volumeMode: Filesystem
  resources:
    requests:
      storage: 5Gi # 资源可以小于 pv 的，但是不能大于，如果大于就会匹配不到 pv
  storageClassName: slow #名字需要与对应的 pv 相同

kubectl create -f pvc-test.yaml
kubectl get pvc

[root@centos7-01 volumes]# kubectl get pv
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   REASON   AGE
pv0001   5Gi        RWO            Recycle          Bound    default/nfs-pvc   slow                    8m16s

[root@centos7-01 volumes]# kubectl get pvc
NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nfs-pvc   Bound    pv0001   5Gi        RWO            slow           83s



步骤三
pod绑定pvc操作

vim test-pvc-pd.yaml

apiVersion: v1
kind: Pod
metadata:
  name: test-pvc-pd
spec:
  containers:
  - image: nginx
    name: nginx-volume
    volumeMounts:
    - mountPath: /usr/share/nginx/html # 挂载到容器的哪个目录
      name: test-volume #挂载哪个volume
  volumes :
    - name: test-volume
      persistentVolumeClaim:
        claimName: nfs-pvc # pvc的名字


kubectl create -f test-pvc-pd.yaml


## StorageClass-每个配置类都有一个制备器，动态创建PV

1.
vim nfs-provisioner-rbac.yaml


apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner 
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
  namespace: kube-system
rules :
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get","list","watch","create","delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get","list","watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get","list","watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create","update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
rules:
  - apiGroups:[""]
    resources:["endpoints"]
    verbs: ["get","list","watch", "create","update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner  # 关键：绑定的Role名称，必须和对应的Role一致
  apiGroup: rbac.authorization.k8s.io           # 固定值，rbac的api组，必填




2.
vim nfs-provisioner-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
  labels:
    app: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template :
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.cn-beijing.aliyuncs.com/pylixm/nfs-subdir-external-provisioner:v4.0.0
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: fuseim.pri/ifs
            - name: NFS_SERVER
              value: 192.168.146.135
            - name: NFS_PATH
              value: /home/nfs/rw

      volumes:
        - name: nfs-client-root
          nfs:
            server: 192.168.146.135
            path: /home/nfs/rw


3.
vim nfs-storage-class.yaml

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage # 外部制备器提供者，编写为提供者的名称
provisioner: fuseim.pri/ifs
parameters:
  archive0nDelete: "false" # 是否存档，false 表示不存档，会删除 oldPath 下面的数据，true 表示存档，会重命名路
reclaimPolicy: Retain # 回收策略，默认为 Delete 可以配置为 Retain
volumeBindingMode: Immediate # 默认为 Immediate,表示创建 PVC 立即进行绑定，只有 azuredisk 和 Awselasticblockstore 支持其他值



4.
vim nfs-sc-demo-statefulset.yaml

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-sc
  labels:
    app: nginx-sc
spec:
  type: NodePort
  ports:
  - name: web
    port: 80
    protocol: TCP
  selector:
    app: nginx-sc
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-sc
spec:
  replicas: 1
  serviceName: "nginx-sc"
  selector:
    matchLabels:
      app: nginx-sc
  template:
    metadata:
      labels:
        app: nginx-sc
    spec:
      containers:
        - image: nginx
          name: nginx-sc
          imagePullPolicy: IfNotPresent
          volumeMounts:
            - mountPath: /usr/share/nginx/html # 挂载到容器的哪个目录
              name: nginx-sc-test-pvc # 挂载哪
  volumeClaimTemplates:
    - metadata:
        name: nginx-sc-test-pvc
      spec:
        storageClassName: managed-nfs-storage
        accessModes:
          - ReadWriteMany
        resources:
          requests:
            storage: 1Gi

单独测试pv
vim auto-pv-test-pvc.yaml

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: auto-pv-test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 300Mi
  storageClassName: managed-nfs-storage


kubectl apply -f nfs-provisioner-rbac.yaml # 先创建权限
kubectl apply -f nfs-provisioner-deployment.yaml # 再创建provisioner
kubectl apply -f nfs-storage-class.yaml # 再创建storage
kubectl apply -f nfs-sc-demo-statefulset.yaml # 创建一个pod检验上述配置


## 高级调度
 
cronjob计划任务

* * * * * 分0-59 时0-23  天1-31 月1-12 周 日-一 


apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  concurrencyPolicy: Allow # 并发调度策略:Allow 允许并发调度，Forbid:不允许并发执行，Replace:如果之前的任务还没执行完，直接执行新的
  failedJobsHistoryLimit: 1 # 保留多少个失败的任务
  successfulJobsHistoryLimit: 3 # 保留多少个成功的任务
  suspend: false # 是否挂起任务，若为 true 则该任务不会执行
  # startingDeadlineSeconds: 30 # 间隔多长时间检测失败的任务并重新执行，时间不能小于 10
  schedule:"* * * * *"  # 调度策略
  jobTemplate :
    spec:
      template:
        spec:
          containers:
            - name: hello
              image: busybox: 1.28
              imagePullPolicy: IfNotPresent
              command:
              - /bin/sh
              - -c
              - date; echo Hello from the Kubernetes cluster
            restartPolicy:OnFailure

kubectl get cj
kubectl edit cj
kubectl describe cj


## 初始化容器

加到
template:
  spec:
    initContainers:
      - image: 


## 污点和容忍

taint 
1. NoSchedule  不能容忍的pod不会被调度，已经存在的不影响
2. NoExecute  不能容忍的pod会立即清除，能容忍的没有配置tolerationSeconds,则一直运行，配置了则运行指定时间

toleration
1.equal key和value必须相同
2.exists 只比较key，只要key存在

kubectl taint node centos7-02  lowmemory:NoSchedule # 添加污点
kubectl taint node centos7-02  lowmemory:NoSchedule-  # 删除存在污点


tolerations:
- effect: NoExecute
  operator: Exists
nodeName: node1 # 指定节点


## 亲和力


节点亲和力

pod亲和力和反亲和力

containers: # 平级

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/os
          operator: In
          values:
          - linux
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 1
      preference:
        matchExpressions:
        - key: label-1
          operator: In
          values:
          - key-1
    - weight: 50
      preference:
        matchExpressions:
        - key: label-2
          operator: In
          values:
          - key-2

给node打标签
kubectl label no centos7-02 kubernetes.io/os=linux

kubectl label no centos7-02 label-1=key-1
kubectl label no centos7-03 label-2=key-2  # 可以看到pod都到centos7-03上面


匹配类型
In，
NotIn，
Exists，
DoesNotExist，
Gt，大于节点上数值才满足
Lt，小于节点上数值才满足



podAffinity

也有硬亲和性和软亲和性


spec:
  affinity:
    podAffinity: # pod亲和性
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - S1
        topologyKey: topology.kubernetes.io/zone
    podAntiAffinity: # pod反亲和性
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: security
              operator: In
              values:
              - S2
          topologyKey: topology.kubernetes.io/zone
  containers:
  - name: with-pod-affinity
    image: nginx


kubectl label no centos7-02 centos7-03 topology.kubernetes.io/zone=V
kubectl label no centos7-01 topology.kubernetes.io/zone=R



## 身份认证和权限

1.认证


kubectl get sa -n kube-system

role # 存在于命名空间
clusterrole # 存在于集群

rolebinding
clusterrolebinding



## helm包管理器

chart


release


# 查看默认仓库
helm repo list
# 添加仓库
helm repo remove bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add aliyun https://apphub.aliyuncs.com/stable
helm repo add azure http://mirror.azure.cn/kubernetes/charts

# 搜索chart
helm search repo redis

# 查看安装说明
helm show readme bitnami/redis

wget https://charts.bitnami.com/bitnami/redis-17.11.1.tgz
tar -zxf
修改values参数，比如storageClass,service，存储大小，密码

kubectl create -n redis
helm install redis(起个名字) ./redis/ -n redis

kubectl exec -it redis-master-0 -n redis -- bash
kubectl exec -it redis-replicas-0 -n redis -- bash

应用升级
helm upgrade redis ./redis -n redis

回滚
helm history redis -n redis
helm rollback redis 1版本号 -n redis

删除
helm delete redis -n redis
helm list -n redis

但pvc没有删除，数据保留

## k8s集群监控

一、自定义配置
1. vim prometheus-config.yml

apiVersion: v1
kind: configMap
metadata:
  name: prometheus-config
  namespace: kube-monitoring
  data:
    prometheus.yml: |
      global:
        scrape_interval: 15s
        evaluation interval: 15s
      scrape_configs:
        - job_name: 'prometheus'
          static_configs:
          - targets: ['localhost:9090']
        - job name: 'kubernetes-nodes'
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
          - role: node
        - job_name: 'kubernetes-service'
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
          -role: service
        - job_name: 'kubernetes-endpoints'
          tls_config:
            ca_file:/var/runsecrets/kubernetes.vTceaceolt/ca.crt
          bearer_token_file: /var/run/secrets/kuberneio/serviceaccount/token
          kubernetes_sd_configs:
          - role: endpoints
        - job_name: 'kubernetes-ingress'
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccoumt/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
          -role: ingress
        - job_name: 'kubernetes-kubelet'
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
          -role: node
          relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
          - target_label: __metrics_path
             replacement: /api/v1/nodes/${l}/proxy/metrics
        - job_name: 'kubernetes-cadvisor'
          scheme: https
          tls_config: ca_file:/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
          - role: node
          relabel_configs:
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target label: __metrics_path__
            replacement: /api/v1/nodes/$[1}/proxy/metrics/cadvisor
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)

        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
          -role: pod
          relabel_configs:
          - source_labels: [__meta_kubernetes _pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: meta_kubernetes_pod_label (.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
        - job_name: 'kubernetes-apiservers'
          kubernetes_sd_configs:
          - role: endpoints
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
            relabel_configs:
            - source_labels: [__meta_kubernetes_namespace, __meta kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
              action: keep
              regex: default;kubernetes;https
            - target_label: __address__
              replacement: kubernetes.default.svc:443
        - job_name: 'kubernetes-services'
          metrics_path: /probe
          params:
            module: [http_2xx]
          kubernetes_sd_configs:
          -role: service
          relabel_configs:
          - source labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
            action: keep
            regex: true
          - source_labels: [__address__]
            target_label: __param_target
          - target_label: __address__
            replacement: blackbox-exporter.default.svc.cluster.local:9115
          - source_labels:[__param_target]
            target_label: instance
          - action: labelmap
            regex: __meta_kubernetes_service_label(.+)
          - source_labels: [__meta_kubernetes_namespace]
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_service_name]
            target_label: kubernetes_name
        - job_name: 'kubernetes-ingresses'
          metrics_path: /probe
          params :
            module:[http_2xx]
          kubernetes_sd_configs:
          -role: ingress
          relabel_configs:
          - source_labels: [__meta_kubernetes_ingress_annotation_prometheus_io_probe]
          action: keep
          regex: true
          - source_labels: [__meta_kubernetes_ingress_scheme,__address__,__meta_kubernetes_ingress_path]
          regex: (.+);(.+);(.+)
          replacement: ${1}://${2}${3}
          target_label: __param_target
        - target_label: __address__
          replacement: blackbox-exporter.default.svc.cluster.local:9115
        - source_labels: [__param_target]
          target_label: instance
        - action: labelmap
          regex: __meta_kubernetes_ingress_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_ingress_name]
          target_label: kubernetes_name


2. vim prometheus-deployment.yml       
          

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    name: prometheus
  name: prometheus
  namespace: kube-monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      serviceAccount: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.2.1
        command:
        - "/bin/prometheus"
        args:
        - "--config.file=/etc/prometheus/prometheus.yml"
        ports:
        - containerPort: 9090
          protocol: TCP
        volumeMounts:
        - mountPath: "/etc/prometheus"
          name: prometheus-config
        - mountPath: "/etc/localtime"
          name: timezone
      volumes :
        - name: prometheus-config
          configMap:
            name: prometheus-config
        - name: timezone
          hostPath:
            path: /usr/share/zoneinfo/Asia/Shanghai
 
3. vim prometheus-rbac-setup.yml


apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: []
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list","watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list","watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: kube-monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: clusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: kube-monitoring

4. vim prometheus-daemonset.yml

apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: kube-monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '9100'
        prometheus.io/path: 'metrics'
      labels:
        app: node-exporter
      name: node-exporter
    spec:
      containers:
      - image: prom/node-exporter
      imagePullPolicy: IfNotPresent
      name: node-exporter
      ports:
      - containerPort: 9100
        hostPort: 9100
        name: scrape
      hostNetwork: true
      hostPID: true

5. vim blackbox-exporter.yml

apiVersion: v1
kind: Service
metadata:
  labels:
    app: blackbox-exporter
    name: blackbox-exporter
  namespace: kube-monitoring
spec:
  ports:
  - name: blackbox
    port: 9115
    protocol: TCP
  selector:
    app: blackbox-exporter
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: blackbox-exporter
  name: blackbox-exporter
  namespace: kube-monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blackbox-exporter
  template:
    metadata:
      labels:
        app: blackbox-exporter
    spec:
      containers:
      - image: prom/blackbox-exporter
        imagePullPolicy: IfNotPresent
        name: blackbox-exporter

6. vim grafana-statefulset.yml

apiVersian: apps/v1
kind: statefulset
metadata:
  name: grafana-core
  namespace: kube-monitoring
  labels:
    app: grafana
    component: core
spec:
  serviceName: "grafana"
  selector:
    matchLabels:
      app: grafana
  replicas: 1
  template:
    metadata:
      labels:
      app: grafana
      component: core
    spec:
      containers:
      - image: grafana/grafana:6.5.3
      name: grafana-core
      imagePullPolicy: IfNotPresent
      env: # The following  variablesset up basic auth twith the default admin user and adinin password.
        - name: GF_AUTH_BASIC_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "false"
        # - name: GF_AUTH_ANONYMOUS_ORG_ROLE
        #   value: Admin
      readinessProbe:
        httpGet:
          path: /login
          port: 3000 # initialDelaySeconds: 30 # timeoutSeconds:1
        volumeMounts:
        - name: grafana-persistent-storage
          mountPath: /var/lib/grafana
          subPath: grafana
  volumeClaimTemplates:
  - metadata:
    name: grafana-persistent-storage
  spec:
    storageClassName: managed-nfs-storage
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: "lGi"

二、kube-prometheus

按k8s下载对应包，1.10
https://github.com/prometheus-operator/kube-prometheus/tree/release-0.10#



sed -i 's/quay.io/quay.mirrors.ustc.edu.cn/g' prometheusOperator-deployment.yaml
sed -i 's/quay.io/quay.mirrors.ustc.edu.cn/g' prometheus-prometheus.yaml
sed -i 's/quay.io/quay.mirrors.ustc.edu.cn/g' alertmanager-alertmanager.yaml
sed -i 's/quay.io/quay.mirrors.ustc.edu.cn/g' kubeStateMetrics-deployment.yaml

这边 image: k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.3.0 换成
image: bitnami/kube-state-metrics:1.9.7

sed -i 's/k8s.gcr.io/lank8s.cn/g' kubeStateMetrics-deployment.yaml
sed -i 's/quay.io/quay.mirrors.ustc.edu.cn/g' nodeExporter-daemonset.yaml
sed -i 's/quay.io/quay.mirrors.ustc.edu.cn/g' prometheusAdapter-deployment.yaml
sed -i 's/k8s.gcr.io/lank8s.cn/g' prometheusAdapter-deployment.yaml
修改镜像
image: k8s.gcr.io/prometheus-adapter/prometheus-adapter:v0.9.1
image: lbbi/prometheus-adapter:v0.9.1

     ## 查看是否还有国外镜像grep "image:"* -r

    # 失败的镜像
k8s.gcr.io/prometheus-adapter/prometheus-adapter:v0.9.1
k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.5.0

    # 平替镜像
docker pull lbbi/prometheus-adapter:v0.9.1
docker pull bitnami/kube-state-metrics

    # 打标签替换
docker tag lbbi/prometheus-adapter:v0.9.1 k8s.gcr.io/prometheus-adapter/prometheus-adapter:v0.9.1
docker tag bitnami/kube-state-metrics:latest  k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.5.0




1.kubectl create -f manifests/setup/
2.kubectl create -f manifests/
3.kubectl get all -n monitoring


vim promethues-ingress.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: monitoring
  name: prometheus-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.wolfcode.cn # 访间 Grafana 域名
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
  - host: prometheus.wolfcode.cn # 访间 Prometheus 域名
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-k8s
            port:
              number: 9090
  - host: alertmanager.wolfcode.cn #访间 alertmanager 域名
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: alertmanager-main
            port:
              number: 9093

修改域名：C:\Windows\System32\drivers\etc\hosts

修改时区
tzselect
Asia/China/Beijing
最后
sudo cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime


## ELK日志管理

1.vim namespace.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: kube-logging



2.vim es.yaml

apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-logging
  namespace: kube-logging
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "Elasticsearch"
spec:
  ports:
  - port: 9200
    protocol: TCP
    targetPort: db
  selector:
    k8s-app: elasticsearch-logging
---
    # RBAC authn and authz
apiVersion: v1
kind: ServiceAccount
metadata:
  name: elasticsearch-logging
  namespace: kube-logging
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---  
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: elasticsearch-logging
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - ""
  resources:
  - "services"
  - "namespaces"
  - "endpoints"
  verbs:
  - "get"
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: kube-logging
  name: elasticsearch-logging
  labels: 
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
subjects:
  - kind: ServiceAccount
    name: elasticsearch-logging
    namespace: kube-logging
    apiGroup: ""
roleRef:
  kind: ClusterRole
  name: elasticsearch-logging
  apiGroup: ""
---
apiVersion: apps/v1
kind: StatefulSet # 使用statefulset创建Pod
metadata:
  name: elasticsearch-logging # pod名称,使用statefulset创建的Pod是有序号有顺序的
  namespace: kube-logging # 命名空间
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    srv: srv-elasticsearch
spec:
  serviceName: elasticsearch-logging # 与svc相关联，这可以确保使用以下DNS地址访间Statefulset中的每个pod (es-cluster-[0,1,2].elasticsearch.elk.svc.cluster.local)
  replicas: 1 # 副本数量,单节点
  selector:
    matchLabels:
      k8s-app: elasticsearch-logging # 和pod template 置的labels相匹配
  template:
    metadata:
      labels:
        k8s-app: elasticsearch-logging
        kubernetes.io/cluster-service: "true"
    spec:
      serviceAccountName: elasticsearch-logging
      containers:
      - image: docker.io/library/elasticsearch:7.9.3
        name: elasticsearch-logging
        resources:
          # need more cpu upon initialization, therefore burstable class
          limits:
            cpu: 1000m
            memory: 2Gi
          requests:
            cpu: 100m
            memory: 500Mi
        ports:
        - containerPort: 9200
          name: db
          protocol: TCP
        - containerPort: 9300
          name: transport
          protocol: TCP
        volumeMounts:
        - name: elasticsearch-logging
          mountPath: /usr/share/elasticsearch/data/ # 挂载点
        env:
        - name: "NAMESPACE"
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: "discovery.type" # 定义单节点类型
          value: "single-node"
        - name: ES_JAVA_OPTS # 设置Java的内存参数，可以适当进行加大调整
          value: "-Xms512m -Xmx2g"
      volumes:
      - name: elasticsearch-logging
        hostPath:
          path: /data/es/
      nodeSelector: #如果需要匹配落盘节点可以添加nodeSelect
        es: data # kubectl label node centos7-03 es=data
      tolerations:
      - effect: NoSchedule
        operator: Exists
      # Elasticsearch requires vm.max_map_count to be at least 262144.If your 0s already sets up this  number to a higher value, feel freeto remove this init container.
      
      initContainers: # 容器初始化前的操作
      - name: elasticsearch-logging-init
        image: alpine:3.6
        command: ["/sbin/sysctl", "-w", "vm.max_map_count=262144"] # 添加mmap计数限制，太低可能造成内存不足的错误
        securityContext: # 仅应用到指定的容器上，并且不会影响Volume
          privileged: true # 运行特权容器
      - name: increase-fd-ulimit
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ["sh", "-c", "ulimit -n 65536"] # 修改文件描述符最大数量
        securityContext:
          privileged: true
      - name: elasticsearch-volume-init # 数据落盘初始化，加上777权限
        image: alpine:3.6
        command:
          - chmod
          - -R
          - "777"
          - /usr/share/elasticsearch/data/
        volumeMounts:
        - name: elasticsearch-logging
          mountPath: /usr/share/elasticsearch/data/

3.vim logstash.yaml

apiVersion: v1
kind: Service
metadata:
  name: logstash
  namespace: kube-logging
spec:
  ports:
  - port: 5044
    targetPort: beats
  selector:
    type: logstash
  clusterIP: None
---  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash
  namespace: kube-logging
spec:
  selector:
    matchLabels:
      type: logstash
  template:
    metadata:
      labels:
        type: logstash
        srv: srv-logstash
    spec:
      containers:
      - image: docker.io/kubeimages/logstash:7.9.3 # 该镜像支持arm64和amd64两种知构
        name: logstash
        ports:
        - containerPort: 5044
          name: beats
        command :
        - logstash
        - '-f'
        - '/etc/logstash_c/logstash.conf'
        env:
        - name: "XPACK_MONITORING_ELASTICSEARCH_HOSTS"
          value: "http://elasticsearch-logging:9200"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/logstash_c/
        - name: config-yml-volume
          mountPath: /usr/share/logstash/config/
        - name: timezone
          mountPath: /etc/localtime
        resources: # logstash一定要加上资源限剂，避免对其他业务造成资源抢占影响
          limits:
            cpu: 1000m
            memory: 2048Mi
          requests:
            cpu: 512m
            memory: 512Mi
      volumes:
      - name: config-volume
        configMap:
          name: logstash-conf
          items:
          - key: logstash.conf
            path: logstash.conf
      - name: timezone
        hostPath:
          path: /etc/localtime
      - name: config-yml-volume
        configMap:
          name: logstash-yml
          items:
            - key: logstash.yml
              path: logstash.yml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-conf
  namespace: kube-logging
  labels:
    type: logstash
data:
  logstash.conf: |-
    input {
      beats {
        port => 5044
      }
    }
    filter {
      if [kubernetes][container][name]== "nginx-ingress-controller" {
        json {
          source => "message"
          target => "ingress_log"
        }

        if [ingress_log][requesttime] {
          mutate {
            convert =>["[ingress_log][requesttime]", "float"]
          }
        }

        if [ingress_log][upstreamtime] {
          mutate {
            convert =>["[ingress_log][upstreamtime]", "float"]
          }
        }

        if [ingress_log][status] {
          mutate {
            convert =>["[ingress_log][status]", "float"]
          }
        }
        
        
        if [ingress_log][httphost] and [ingress_log][uri] {
          mutate {
            add_field => {"[ingress_log][entry]" => "%{[ingress_log][httphost]}%{[ingress_log][uri]}"}
          }

          mutate {
            split => ["[ingress_log][entry]","/"]
          }
          
          if [ingress_log][entry][1] {
            mutate {
                add_field => {"[ingress_log][entrypoint]" => "%{[ingress_log][entry][0]}/%{[ingress_log][entry][1]}"}
                remove_field => "[ingress_log][entry]"
            }
          
          } else {
          
            mutate {
                add_field => {"[ingress_log][entrypoint]" => "%{[ingress_log][entry][0]}/"}
                remove_field => "[ingress_log][entry]"
              }
          }
        
        }
      
      }
      
      # 处理以srv开头的业务服务日志
      if [kubernetes][container][name] =~ /^srv*/ {
        json {
          source => "message"
          target => "tmp"
        }
        if [kubernetes][namespace] == "kube-logging" {
            drop{}
        }
        if [tmp][level] {
          mutate{
            add_field => {"[applog][level]" => "%{[tmp][level]}"}
          }
          if [applog][level] == "debug" {
            drop{}
          }
        }
        if [tmp][msg] {
          mutate {
            add_field => {"[apptog][msg]" => "%{[tmp][msg]}"}
          }
        }
        if [tmp][func] {
          mutate {
            add_field => {"[apptog][func]" => "%{[tmp][func]}"}
          }
        }
        
        if [tmp][cost] {
          if "ms" in [tmp][cost] {
            mutate {
              split => ["[tmp][cost]","m"]
              add_field => {"[epplog][cost]" => "%{[tmp][cost][0]}"}
              convert => ["[applog][cost]","float"]
            }
          } else {
            mutate {
              add_field => {"[applog][cost]" => "%{[tmp][cost]}"}
            }
          } 
        }
        
        if [tmp][method] {
          mutate {
            add_field => {"[applog][method]" => "%{[tmp][method]}"}
          }
        }
        if [tmp][request_url] {
          mutate {
            add_field => {"[applog][request_url]" => "%{[tmp][request_url]}"}
          }
        }
        if [tmp][meta._id] {
          mutate {
            add_field => {"[applog][traceId]" => "%{[tmp][meta._id]}"}  
          }
        }
        if [tmp][project] {
          mutate {
            add_field => {"[applog][project]" => "%{[tmp][project]}"}
          }
        }
        if [tmp][time] {
          mutate {
            add_field => {"[applog][time]" => "%{[tmp][time]}"}
          }
        }
        if [tmp][status] {
          mutate {
            add_field => {"[applog][status]" => "%{[tmp][status]}"}
            convert => ["[applog][status]", "float"]
          }
        }
      }
      mutate {
        remove => {"kubernetes","k8s"}
        remove_field => "beat"
        remove_field => "tmp"
        remove_field => "[k8s][labels][app]"
      }
   
    }

    output {
      elasticsearch {
        hosts => ["http://elasticsearch-logging:9200"]
        codec => json
        index => "logstash-%{+YYYY.MM.dd}" # 索引名称以logstash+日志进行每日新建
      }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-yml
  namespace: kube-logging
  labels:
    type: logstash
data:
  logstash.yml: |-
    http.host: "0.0.0.0"
    xpack.monitoring.elasticsearch.hosts: http://elasticsearch-logging:9200





3.vim filebeat.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: kube-logging
labels:
  k8s-app: filebeat
data:
  filebeat.yml: |-
    filebeat.inputs:
    - type: container
      enable: true
      paths:
        - /var/log/containers/*.log # 这里是filebeat采集挂载到pod中的日志目录
      processors:
        - add_kubernetes_metadata: # 添加k8s的字段用于后续的数据清洗
          host: ${NODE_NAME}
          matchers:
          - logs_path:
              logs_path: "/var/log/containers/" 
              # output.kafka: #如果日志量较大，es中的日志有延迟，可以选择在filebeat和logstash中间加入kafka# hosts:["kafka-log-01:9092","kafka-log-02:9092","kafka-log-03:9092"]# topic:'topic-test-log'
              #version:2.0.0
    output.logstash: # 因为还需要部署logstash进行数据的清洗，因此filebeat是把数据推到logstash中
      hosts: ["logstash:5044"]
      enabled: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: kube-logging
  labels:
    k8s-app: filebeat
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
  labels:
    k8s-app: filebeat
rules:
- apiGroups: [""] # "" indicates the core API group
  resources:
  - namespaces
  - pods
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: kube-logging
roleRef:
  kind: ClusterRole
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: kube-logging
  labels:
    k8s-app: filebeat

spec:
  selector:
    matchLabels:
      k8s-app: filebeat
  template:
    metadata:
      labels:
        k8s-app: filebeat
    spec:
      serviceAccountName: filebeat
      terminationGracePeriodSeconds: 30
      containers:
      - name: filebeat
        image: docker.io/kubeimages/filebeat:7.9.3 #该镜像支持arm64和amd64两种架构
        args: [ 
          "-c", "/etc/filebeat.yml",
          "-e", "-httpprof","0.0.0.0:6060"
        ]      
        #ports:
        #-containerPort:6060
        #hostPort:6068
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: ELASTICSEARCH_HOST
          value: etasticsearch-logging
        - name: ELASTICSEARCH_PORT
          value: "9200"
        securityContext:
          runAsUser: 0
          # If using Red Hat OpenShift uncomment this:
          #privileged: true
        resources:
          limits:
            memory: 1000Mi
            cpu: 1000m
          requests:
            memory: 100Mi
            cpu: 100m
        volumeMounts:
        - name: config #挂载的是filebeat的配置文件
          mountPath: /etc/filebeat.yml
          readOnly: true
          subPath: filebeat.yml
        - name: data #持久化filebeat数据到宿主机上
          mountPath: /usr/share/filebeat/data
        - name: varlibdockercontainers #这里主要是把宿主机上的源日志日求挂载到filebeat容器中,如果没有修改docker或者containerd的runtime进行了标准的日志落盘路径，可以把mountPath改为/var/lib
          mountPath: /var/lib
          readOnly: true
        - name: varlog #这里主要是把宿主机上/var/log/pods和/var/log/containers的软链接挂载到filebeat容器中
          mountPath: /var/log/
          readOnly: true
        - name: timezone
          mountPath: /etc/localtime
      volumes:
      - name: config
        configMap:
          defaultMode: 0600
          name: filebeat-config
      - name: varlibdockercontainers
        hostPath: #如果没修改docker或者containerd的runtime进行了标准的目志落盘路径，可以把path改为/var/lib
          path: /var/lib
      - name: varlog
        hostPath:
          path: /var/log/
      # data folder stores a registry of read status for all files, so we don't send everything again on a Filebeat pod restart
      - name: inputs
        configMap:
          defaultMode: 0600
          name: filebeat-inputs
      - name: data
        hostPath:
          path: /data/filebeat-data
          type: DirectoryOrCreate
      - name: timezone
        hostPath:
          path: /etc/localtime
      tolerations: #加入容忍能够调度到每一个节点
      - effect: NoExecute
        key: dedicated
        operator: Equal
        value: gpu
      - effect: NoSchedule
        operator: Exists

4.vim kibana.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  namespace: kube-logging
  name: kibana-config
labels:
  k8s-app: kibana
data:
  kibana.yml: |-
    server.name: kibana
    server.host: "0"
    i18n.locale: zh-CN # 设置默认语言为中文
    elasticsearch:
      hosts: ${ELASTICSEARCH_HOSTS} #es集群连接地址，由于我这都都是k8s部署且在一个ns下，可以直接使用service name连接
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    k8s-app: kibana
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "Kibana"
    srv: srv-kibana
spec:
  type: NodePort
  ports:
  - port: 5601
  protocol: TCP
  targetPort: ui
  selector:
    k8s-app: kibana
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    k8s-app: kibana
    kubernetes.io/cluster-service:"true"
    addonmanager.kubernetes.io/mode: Reconcile
    srv: srv-kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kibana
  template:
    metadata:
      labels:
        k8s-app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.io/kubeimages/kibana:7.9.3 #该镜像支持arm64和amd64两种架构
        resources:
        # need more cpu upon initialization, therefore burstable class
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        env:
          - name: ELASTICSEARCH_HOSTS
            value: http://elasticsearch-logging:9200
        ports:
        - containerPort: 5601
          name: ui
          protocol: TCP
        volumeMounts:
        - name: config
          mountPath: /usr/share/kibana/config/kibana.yml
          readOnly: true
          subPath: kibana.yml
      volumes:
      - name: config
        configMap:
          name: kibana-config
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kibana
  namespace: kube-logging
spec:
  ingressClassName: nginx
  rules:
  - host: kibapa.wolfcode.cn
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kibana
            port:
              number: 5601