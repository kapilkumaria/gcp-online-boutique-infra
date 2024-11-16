#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)
set -euxo pipefail

# Kubernetes Variable Declaration
KUBERNETES_VERSION="v1.30"
CRIO_VERSION="v1.30"
KUBERNETES_INSTALL_VERSION="1.30.0-1.1"
CRIO_REPO_URL="https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/"
KUBERNETES_REPO_URL="https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/"

# Update and upgrade packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Disable swap
sudo swapoff -a || true
if ! crontab -l | grep -q "@reboot /sbin/swapoff -a"; then
    (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -
fi

# Load necessary modules
sudo mkdir -p /etc/modules-load.d
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay || true
sudo modprobe br_netfilter || true

# Apply sysctl params
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system || true

# Install CRI-O Runtime
if ! dpkg -s cri-o &>/dev/null; then
    sudo apt-get install -y apt-transport-https ca-certificates
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL "$CRIO_REPO_URL/Release.key" | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] $CRIO_REPO_URL /" | sudo tee /etc/apt/sources.list.d/cri-o.list
    sudo apt-get update -y
    sudo apt-get install -y cri-o
    sudo systemctl enable crio --now
fi

# Install Kubernetes tools
if ! dpkg -s kubelet kubectl kubeadm &>/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL "$KUBERNETES_REPO_URL/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] $KUBERNETES_REPO_URL /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update -y
    sudo apt-get install -y kubelet="$KUBERNETES_INSTALL_VERSION" kubectl="$KUBERNETES_INSTALL_VERSION" kubeadm="$KUBERNETES_INSTALL_VERSION"
    sudo apt-mark hold kubelet kubeadm kubectl
fi

# Install jq
sudo apt-get install -y jq || true

# Retrieve primary interface and set node IP
primary_interface=$(ip -o -4 route show to default | awk '{print $5}')
local_ip=$(ip --json addr show "$primary_interface" | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')
cat > /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF

# Create marker file
echo "$(date '+%Y-%m-%d %H:%M:%S') - common.sh executed successfully" > /tmp/common_sh_executed.marker
