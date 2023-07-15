#!/bin/bash

echo "[TASK 1] Pull required containers"
sudo kubeadm config images pull

echo "[TASK 2] Initialize Kubernetes Cluster"
VAR_NODE_IP="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
sudo kubeadm init --apiserver-advertise-address=$VAR_NODE_IP --apiserver-cert-extra-sans=$VAR_NODE_IP --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=$VAR_NODE_IP:6443

echo "[TASK 3] Deploy CNI (Weavenet)"
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

echo "[TASK 4] Generate and save cluster join command to kubeadm_join.sh"
sudo mkdir -p /opt/vagrant/data/.k8s
sudo kubeadm token create --print-join-command >> /opt/vagrant/data/.k8s/kubeadm_join.sh
