cat <<EOF >./log
    脚本名：$0
    脚本第一个参数：$1
    脚本第二个参数：$2
    脚本参数总个数：$#
    脚本所有参数：$@
    当前时间：`date +%F`
    当前时间：$(date +%F)
EOF


num1="$1"
num2="$2"
echo "第一个参数：$num1,第二个参数：$num2"
echo "主机名：`hostname`"
echo "pid：$$"

expr "$num1" + "$num2" + 666 &>/dev/null

if [ $? -ne 0 ]; then
    echo "$0 "
    echo "请输入数字"
fi

plus=`awk -v n1=$num1 -v n2=$num2 'BEGIN{ print n1+n2 }'`
minus=`awk -v n1=$num1 -v n2=$num2 'BEGIN{ print n1-n2 }'`
cat <<EOF
    计算 $num1 + $num2 = $plus
    计算 $num1 - $num2 = $minus
EOF

ip_remote="192.168.146.129 192.168.146.130 192.168.146.131"

for ip in ${ip_remote}
do
    echo "$ip 密钥已发送"
done
