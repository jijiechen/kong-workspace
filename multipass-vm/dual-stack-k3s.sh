
multipass launch focal --name v6 \
    --cpus 4 --disk 80G --memory 8G \
    --mount /Users/$USER:/opt/host \
    --timeout 600

sudo mkdir -p /etc/rancher/k3s/
sudo cat << EOF > /etc/rancher/k3s/config.yaml
disable-network-policy: true
flannel-ipv6-masq: true
disable:
  - traefik
  - metrics-server
  - servicelb
cluster-cidr:
  - 10.42.0.0/16
  - fd00:fd12:1234::0/56
service-cidr:
  - 10.43.0.0/16
  - fd00:fd12:5678:abcd::0/108
node-ip:
  - 192.168.64.4
  - fd3c:b13f:7ad7:111f:5054:ff:fea8:c289
kubelet-arg: "node-ip=0.0.0.0"
EOF

export INSTALL_K3S_VERSION=v1.27.9+k3s1
curl -sfL https://get.k3s.io | sh -
# k3s-killall.sh
# sudo k3s server --disable-network-policy --disable=traefik --disable=metrics-server --disable=servicelb --cluster-cidr=10.42.0.0/16,2001:cafe:42::/56 --service-cidr=10.43.0.0/16,2001:cafe:43::/112 --flannel-ipv6-masq --node-ip='192.168.64.4,fd3c:b13f:7ad7:111f:5054:ff:fea8:c289' --kubelet-arg="node-ip=0.0.0.0"

sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chmod 666 ~/.kube/config
