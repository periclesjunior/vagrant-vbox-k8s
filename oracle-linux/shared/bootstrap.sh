#!/bin/bash

echo "[TASK 1] Install packages"
dnf install jq iproute-tc bash-completion dnf-utils -y

echo "[TASK 2] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 3] Stop and Disable FirewallD"
systemctl disable --now firewalld

echo "[TASK 4] Set SELinux in permissive mode"
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "[TASK 5] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 6] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 7] Add repo and install containerd runtime"
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install containerd.io -y
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
cat >>/etc/crictl.yaml<<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 30
debug: false
EOF
systemctl enable --now containerd >/dev/null

echo "[TASK 8] Add apt repo for kubernetes"
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

echo "[TASK 9] Install Kubernetes components (kubeadm, kubelet and kubectl)"
# List packages version with:
# dnf list --enablerepo=kubernetes --showduplicates --disableexcludes=kubernetes kubeadm
dnf install kubelet-1.29.0 kubeadm-1.29.0 kubectl-1.29.0 --disableexcludes=kubernetes -y

echo "[TASK 10] Adjust pause image"
# Adjust pause image to what's actually installed
VAR_PAUSE_IMAGE=$(kubeadm config images list | grep pause)
sed -i "s,sandbox_image = .*,sandbox_image = \"$VAR_PAUSE_IMAGE\",g" /etc/containerd/config.toml
systemctl restart containerd

echo "[TASK 11] kubelet settings"
VAR_NODE_IP="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat >/etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=$VAR_NODE_IP
EOF
systemctl enable kubelet

echo "[TASK 12] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
192.168.56.250   control-plane.example.com    control-plane
192.168.56.251   node001.example.com    node001
192.168.56.252   node002.example.com    node002
EOF
