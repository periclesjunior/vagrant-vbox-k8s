#!/bin/bash

VAR_K8S_VERSION="1.33"

export DEBIAN_FRONTEND=noninteractive

echo "[TASK 1] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 2] Stop and Disable firewall"
systemctl disable --now ufw >/dev/null 2>&1

echo "[TASK 3] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 4] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 5] Install containerd runtime"
apt-get update -qq >/dev/null
apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release jq bash-completion >/dev/null
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq >/dev/null
apt-get install -qq -y containerd.io >/dev/null
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
cat >>/etc/crictl.yaml<<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 30
debug: false
EOF
systemctl enable --now containerd >/dev/null

echo "[TASK 6] Set up kubernetes repo"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${VAR_K8S_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v${VAR_K8S_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

echo "[TASK 7] Install Kubernetes components (kubeadm, kubelet and kubectl)"
apt-get update -qq >/dev/null
apt-get install -qq -y kubeadm kubelet kubectl >/dev/null

echo "[TASK 8] Adjust pause image"
# Adjust pause image to what's actually installed
VAR_PAUSE_IMAGE=$(kubeadm config images list | grep pause)
sed -i "s,sandbox_image = .*,sandbox_image = \"$VAR_PAUSE_IMAGE\",g" /etc/containerd/config.toml
systemctl restart containerd

echo "[TASK 9] kubelet settings"
VAR_NODE_IP="$(ip --json a s | jq -r '.[] | if .ifname == "enp0s8" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat >/etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=$VAR_NODE_IP
EOF
systemctl enable kubelet

echo "[TASK 10] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
192.168.56.250   control-plane.example.com    control-plane
192.168.56.251   node-001.example.com    node-001
192.168.56.252   node-002.example.com    node-002
EOF
