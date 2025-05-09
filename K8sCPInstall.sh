#!/bin/bash

#############################################################
#### Script para instalar Kubernetes control plane nodes ####
#############################################################

set -e

echo "=== Actualizando el sistema ==="
sudo apt update && sudo apt upgrade -y

echo "=== Desactivando swap ==="
sudo swapoff -a
sudo sed -i.bak '/\bswap\b/ s/^/#/' /etc/fstab

echo "=== Instalando dependencias ==="
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

echo "=== Configurando parámetros del kernel ==="
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "=== Instalando Containerd ==="
sudo apt install -y containerd

echo "=== Configurando Containerd ==="
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

echo "=== Reiniciando y habilitando Containerd ==="
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== Agregando repositorio de Kubernetes ==="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "=== Instalando kubelet, kubeadm y kubectl ==="
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "=== Habilitando kubelet ==="
sudo systemctl enable kubelet

echo "=== Instalación completada ==="

echo "=== Inicializar el cluster ==="
sudo kubeadm init --pod-network-cidr=172.16.0.0/16 > ClusterJoin.txt


echo "=== Configurar Kubectl para no usar root ==="
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> ~/.bashrc

echo "=== Instalar helm ==="
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

echo "=== Instalar cilium ==="
helm repo add cilium https://helm.cilium.io/
helm repo update
helm template cilium cilium/cilium --version 1.16.1 \
--namespace kube-system > cilium.yaml
kubectl apply -f cilium.yaml

echo "=== Usa el siguiente comando para unir un worker al cluster ==="
cat ClusterJoin.txt
