passwd = 123
ips="192.168.146.129 192.168.146.130 192.168.146.131"

if  [ -f ~/.ssh/id_isa ]; then
    echo "已经创建过rsa"
else
    echo "正在创建rsa..."
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' &>/dev/null
fi

for ip in $ips
do
    sshpass -p $passwd ssh-copy-id -i  ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no $ip &/dev/null
    echo "$ip 密钥已发送"
done
