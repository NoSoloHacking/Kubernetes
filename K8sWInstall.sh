#!/bin/bash

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

echo "Ahora une el Worker ejecutando el comando kubeadm join con el token generado en la instalación del nodo de control ==="