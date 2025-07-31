#!/bin/bash

VAR_CALICO_VERSION="3.30.2"
VAR_METRICS_SERVER_VERSION="0.8.0"

echo "[TASK 1] Pull required containers"
kubeadm config images pull

echo "[TASK 2] Initialize Kubernetes Cluster"
VAR_NODE_IP="$(ip --json a s | jq -r '.[] | if .ifname == "enp0s8" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
kubeadm init --apiserver-advertise-address=$VAR_NODE_IP --apiserver-cert-extra-sans=$VAR_NODE_IP --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=$VAR_NODE_IP:6443

echo "[TASK 3] Deploy CNI (Calico)"
kubectl --kubeconfig /etc/kubernetes/admin.conf create -f https://raw.githubusercontent.com/projectcalico/calico/v$VAR_CALICO_VERSION/manifests/calico.yaml

echo "[TASK 4] Deploy Metrics Server"
kubectl --kubeconfig /etc/kubernetes/admin.conf create -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v$VAR_METRICS_SERVER_VERSION/components.yaml
# Enable Kubelet Insecure TLS for Metrics Server
kubectl --kubeconfig /etc/kubernetes/admin.conf patch deployment/metrics-server -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

echo "[TASK 5] Configure kubeconfig"
sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

echo "[TASK 6] Generate and save cluster join command to kubeadm_join.sh"
rm -rf /opt/vagrant/data/.k8s && mkdir -p /opt/vagrant/data/.k8s
kubeadm token create --print-join-command >> /opt/vagrant/data/.k8s/kubeadm_join.sh
