#!/bin/bash

echo "[TASK 0] Install packages"
sudo dnf install jq iproute-tc bash-completion dnf-utils -y

echo "[TASK 1] Disable and turn off SWAP"
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

echo "[TASK 2] Stop and Disable FirewallD"
sudo systemctl disable --now firewalld

echo "[TASK 3] Set SELinux in permissive mode"
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "[TASK 4] Enable and Load Kernel modules"
sudo cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "[TASK 5] Add Kernel settings"
sudo cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system >/dev/null 2>&1

echo "[TASK 6] Add repo and install containerd runtime"
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install containerd.io -y
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo cat >>/etc/crictl.yaml<<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 30
debug: false
EOF
sudo systemctl enable --now containerd

echo "[TASK 7] Add apt repo for kubernetes"
sudo cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

echo "[TASK 8] Install Kubernetes components (kubeadm, kubelet and kubectl)"
dnf install kubelet kubeadm kubectl --disableexcludes=kubernetes -y

echo "[TASK 9] kubelet settings"
VAR_NODE_IP="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat >/etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=$VAR_NODE_IP
EOF
systemctl enable kubelet

echo "[TASK 10] Update /etc/hosts file"
sudo cat >>/etc/hosts<<EOF
192.168.56.250   control-plane.example.com    control-plane
192.168.56.251   node001.example.com    node001
192.168.56.252   node002.example.com    node002
EOF
