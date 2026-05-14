#!/usr/bin/env python
# -*- coding: utf-8 -*- 
import requests
import json
import sys
import os
import datetime
import logging
 
# 配置日志（修复路径）
LOG_FILE = "/usr/lib/zabbix/alertscripts/log/dingding.log"
LOG_DIR = os.path.dirname(LOG_FILE)
 
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR, exist_ok=True)
 
logging.basicConfig(
    filename=LOG_FILE,
    format='%(asctime)s - %(message)s',
    level=logging.INFO
)
 
webhook = "https://oapi.dingtalk.com/robot/send?access_token=ddd766d19bf8151b84732db8bc88a9ec0f19f2bbd9791d7583397eb110f407b7"
user = sys.argv[1]
subject = sys.argv[2] + " "  # 确保主题与内容分离
text = sys.argv[3]
 
# 转义特殊字符
safe_text = text.replace("<", "&lt;").replace(">", "&gt;")
 
data = {
    "msgtype": "text",
    "text": {
        "content": f"{subject}{safe_text}"
    },
    "at": {
        "atMobiles": [user],
        "isAtAll": False
    }
}
 
headers = {'Content-Type': 'application/json'}
status = "未知"
 
try:
    # 增加超时和重试
    response = requests.post(
        webhook,
        data=json.dumps(data),
        headers=headers,
        timeout=5
    )
    
    # 记录完整响应
    logging.info(f"请求数据: {json.dumps(data)}")
    logging.info(f"钉钉响应: {response.status_code} {response.text}")
    
    if response.status_code == 200:
        result = response.json()
        if result.get("errcode") == 0:
            status = "发送成功"
        else:
            status = f"钉钉错误: {result.get('errmsg')}"
    else:
        status = f"HTTP错误: {response.status_code}"
        
except Exception as e:
    status = f"异常错误: {str(e)}"
    logging.error(status)
 
# 最终记录结果
logging.info(f"{datetime.datetime.now()} | {user} | {status}")
print(status)  # Zabbix需要标准输出