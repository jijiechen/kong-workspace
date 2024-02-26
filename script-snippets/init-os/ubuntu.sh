#!/bin/bash

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# set mirror
sudo sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
sudo apt -y remove needrestart

# install oh-my-zsh
sudo apt install -y zsh
chsh -s /usr/bin/zsh $(whoami)
sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
sed -i 's/plugins=(git)/plugins=(fzf git zsh-autosuggestions zsh-syntax-highlighting virtualenv colored-man-pages kubectl colorize)/g' ~/.zshrc
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.zshrc

# clone workspace and setup
mkdir -p ~/go/src/github.com/jijiechen/kong-workspace
(cd ~/go/src/github.com/jijiechen/kong-workspace && git clone https://github.com/jijiechen/kong-workspace.git .)

echo "source ~/go/src/github.com/jijiechen/kong-workspace/script-snippets/.bash_rc.sh" >> ~/.bashrc
echo "source ~/go/src/github.com/jijiechen/kong-workspace/script-snippets/.bash_rc.sh" >> ~/.zshrc


# disable unnecessary services
sudo systemctl disable man-db.timer man-db.service --now
sudo systemctl disable apport.service apport-autoreport.service  --now
sudo systemctl disable apt-daily.service apt-daily.timer --now
sudo systemctl disable apt-daily-upgrade.service apt-daily-upgrade.timer --now
sudo systemctl disable unattended-upgrades.service --now
sudo systemctl disable motd-news.service motd-news.timer --now
sudo systemctl disable bluetooth.target --now
sudo systemctl disable ua-timer.timer ua-timer.service --now
sudo systemctl disable systemd-tmpfiles-clean.timer --now

echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf

# enable forwarding to enable networking from host to docker in VM
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.proxy_arp=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.proxy_arp=1

sudo sysctl -p


# install common tools
$SCRIPT_PATH/go.sh

$SCRIPT_PATH/dev-tools.sh

$SCRIPT_PATH/cloud-cli.sh