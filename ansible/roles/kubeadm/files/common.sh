#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)
sudo apt update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y

set -euxo pipefail

# Kubernetes Variable Declaration
KUBERNETES_VERSION="v1.30"
CRIO_VERSION="v1.30"
KUBERNETES_INSTALL_VERSION="1.30.0-1.1"

# Disable swap if not already done
sudo swapoff -a || true

# Keeps the swap off during reboot
if ! crontab -l | grep -q "@reboot /sbin/swapoff -a"; then
    (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -
fi

# Update package list
sudo apt-get update -y

# Load necessary modules if not already loaded
if ! grep -q "overlay" /etc/modules-load.d/k8s.conf 2>/dev/null || ! grep -q "br_netfilter" /etc/modules-load.d/k8s.conf 2>/dev/null; then
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    sudo modprobe overlay || true
    sudo modprobe br_netfilter || true
fi

# Apply sysctl params if not already configured
if ! grep -q "net.bridge.bridge-nf-call-iptables = 1" /etc/sysctl.d/k8s.conf 2>/dev/null; then
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sudo sysctl --system
fi

# Ensure required packages are installed
sudo apt-get install -y apt-transport-https ca-certificates curl gpg || true

# Install CRI-O Runtime if not already installed
if ! dpkg -s cri-o &> /dev/null; then
    echo "Installing CRI-O runtime..."
    sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates
    curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list
    sudo apt-get update -y
    sudo apt-get install -y cri-o
    sudo systemctl daemon-reload
    sudo systemctl enable crio --now
    sudo systemctl start crio.service
    echo "CRI runtime installed successfully"
fi

# Install kubelet, kubectl, and kubeadm if not already installed
if ! dpkg -s kubelet kubectl kubeadm &> /dev/null; then
    echo "Installing Kubernetes tools..."
    curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update -y
    sudo apt-get install -y kubelet="$KUBERNETES_INSTALL_VERSION" kubectl="$KUBERNETES_INSTALL_VERSION" kubeadm="$KUBERNETES_INSTALL_VERSION"
    sudo apt-mark hold kubelet kubeadm kubectl
    echo "Kubernetes tools installed successfully"
fi

# Install jq if not already installed
if ! dpkg -s jq &> /dev/null; then
    sudo apt-get install -y jq
fi

# Retrieve the local IP address of the eth0 interface and set it for kubelet
local_ip="$(ip --json addr show enX0 | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')"

# Write the local IP address to the kubelet default configuration file if not already set
if ! grep -q "KUBELET_EXTRA_ARGS=--node-ip=$local_ip" /etc/default/kubelet 2>/dev/null; then
    cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF
fi

# Create a marker file to indicate successful execution
touch /tmp/common_sh_executed.marker
