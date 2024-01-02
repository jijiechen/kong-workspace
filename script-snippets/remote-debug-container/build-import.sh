
# build base:
# git clone https://github.com/robertdebock/docker-centos-openssh.git
# cd docker-centos-openssh


# docker buildx create --name multiarch --driver docker-container
# docker buildx build --platform linux/arm64,linux/amd64  -t jijiechen/centos8-openssh:202312 --builder multiarch --push .

# base for only local usage:
# docker buildx build --platform linux/arm64 -t jijiechen/centos8-openssh:202312 --builder multiarch --load .


docker build -t jijiechen/remote-vscode:golang-centos8-20240102 .
k3d image import jijiechen/remote-vscode:golang-centos8-20240102  --cluster $CLUSTER_NAME --mode direct