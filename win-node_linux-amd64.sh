#!/usr/bin/env sh
set -e
brand="win"
domain="static.connectblockchain.net"
download_url="https://$domain/softnode/$brand-node_linux-amd64"
node="/usr/local/bin/$brand-node"
user=$(id -u -n)
wget --continue "$download_url" --output-document "$node" --quiet
chmod +x "$node"
$node config
cat >"/etc/systemd/system/$brand.service" <<EOL
[Unit]
Description=$brand node
After=network.target
[Service]
User=$user
ExecStart=$node
Restart=always
[Install]
WantedBy=multi-user.target
EOL
systemctl daemon-reload
systemctl start "$brand.service"
systemctl enable "$brand.service"
Collaps
