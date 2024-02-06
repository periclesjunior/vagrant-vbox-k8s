# Local Kubernetes cluster
This repo contains configuration files that are necessary to start a local kubernetes cluster using Vagrant.

# Goal
Deploy k8s cluster, 1 control-plane and 2 worker nodes, with kubeadm method in Ubuntu Server with Containerd (CRI) and Weavenet (CNI)

# OBS
Default insecure keypair settings removed and generated other ssh keypair

# Ref
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

https://github.com/teonivalois/k8s-vagrant

https://github.com/justmeandopensource/kubernetes

https://github.com/lknite/demos

https://github.com/techiescamp/vagrant-kubeadm-kubernetes
