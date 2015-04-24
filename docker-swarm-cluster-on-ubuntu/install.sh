#!/bin/bash

ETCDIP=$2
ID=$1
NODEIP=$(ip -4 addr show dev eth0|grep inet|sed "s#/.*##;s/.* //")

echo Exposing Docker on TCP
cat > /etc/systemd/system/docker-tcp.socket <<EOF
[Unit]
Description=Docker Socket for the API

[Socket]
ListenStream=2375
BindIPv6Only=both
Service=docker.service

[Install]
WantedBy=sockets.target
EOF

systemctl enable docker-tcp.socket
systemctl stop docker
systemctl start docker-tcp.socket
systemctl start docker

echo Installing Swarm Agent service
cat > /etc/systemd/system/swarm-agent.service <<EOF
[Unit]
Description=Swarm Agent
After=docker.service
After=etcd.service
Requires=docker.service
Requires=etcd.service

[Service]
TimeoutStartSec=0
ExecStartPre=-/usr/bin/docker kill swarmagent
ExecStartPre=-/usr/bin/docker rm swarmagent
ExecStartPre=/usr/bin/docker pull swarm
ExecStart=/usr/bin/docker run --name swarmagent swarm join --addr ${NODEIP}:2375 etcd://${ETCDIP}:4001/swarm

[Install]
WantedBy=multi-user.target
EOF

systemctl enable swarm-agent
systemctl start swarm-agent

if [[ "${NODEID}" -eq "0" ]]; then 
	echo Installing Swarm Management service
	cat > /etc/systemd/system/swarm-manager.service <<EOF
[Unit]
Description=Swarm Manager
After=docker.service
After=etcd.service
Requires=docker.service
Requires=etcd.service

[Service]
TimeoutStartSec=0
ExecStartPre=-/usr/bin/docker kill swarmmanager
ExecStartPre=-/usr/bin/docker rm swarmmanager
ExecStartPre=/usr/bin/docker pull swarm
ExecStart=/usr/bin/docker run -p 4242:4242 --name swarmmanager swarm manage -H 0.0.0.0:4242 etcd://${ETCDIP}:4001/swarm

[Install]
WantedBy=multi-user.target
EOF

	systemctl enable swarm-manager
	systemctl start swarm-manager
fi
