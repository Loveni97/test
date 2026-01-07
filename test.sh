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

if [ 1=1 ]; then
    echo "yes"
fi

