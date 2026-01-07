1.安装Node Exporter
安装包位置是在/opt/node_exporter/node_exporter
cat > /usr/lib/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=node_exporter
Documentation=https://github.com/prometheus/node_exporter
After=network.target
 
[Service]
Type=simple
User=root
ExecStart=/opt/node_exporter/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable node_exporter
systemctl start node_exporter

验证
curl http://localhost:9100/metrics

2. 部署Prometheus服务器
创建系统服务
安装包位置/opt/prometheus/prometheus，根据实际修改


vim /etc/prometheus/targets/nodes.json
[
  {
    "targets": ["192.168.1.101:9100", "192.168.1.102:9100"],
    "labels": {
      "env": "production",
      "role": "web"
    }
  },
  {
    "targets": ["192.168.1.103:9100", "192.168.1.104:9100"],
    "labels": {
      "env": "staging",
      "role": "db"
    }
  }
]

关于/opt/prometheus/prometheus.yml参数设置
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus"

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ["192.168.88.133:9090"]
  - job_name: "node_exporter"
    # static_configs:
      #  - targets: ["192.168.88.133:9100"]
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/*.json'
        refresh_interval: 5m



cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
User=root
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus
systemctl status prometheus

3. 部署Grafana

# 启动服务
systemctl start grafana-server
systemctl enable grafana-server
systemctl status grafana-server

nohup ./bin/grafana-server web>./grafana.log 2>&1 &
nohup ./prometheus --config.file=prometheus.yml > .prometheus.log 2>&1 &




