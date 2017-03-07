#!/bin/bash
set -e

PUBLIC_IP=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)
CF_DOMAIN=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4).nip.io
echo "\n"
echo "CF_DOMAIN=${CF_DOMAIN}" > .ssh/environment
sudo sed -i 's/PermitUserEnvironment no/PermitUserEnvironment yes/g' /etc/ssh/sshd_config
sudo bash -c 'echo "MaxSessions 1000" >> /etc/ssh/sshd_config'
sudo bash -c 'echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config'
sudo sed -i '/ClientAliveInterval/d' /etc/ssh/sshd_config
sudo sed -i '/ClientAliveCountMax/d' /etc/ssh/sshd_config
sudo sed -i 's/AcceptEnv .*/AcceptEnv \*/g' /etc/ssh/sshd_config
sudo service ssh restart
sudo start-cf "$CF_DOMAIN"


sudo PUBLIC_IP=$PUBLIC_IP CF_DOMAIN=$CF_DOMAIN bash -c 'cat >> /etc/hosts <<EOF
$PUBLIC_IP api.$CF_DOMAIN
$PUBLIC_IP login.$CF_DOMAIN
$PUBLIC_IP uaa.$CF_DOMAIN
$PUBLIC_IP loggregator.$CF_DOMAIN
$PUBLIC_IP doppler.$CF_DOMAIN
$PUBLIC_IP blobstore.$CF_DOMAIN
EOF'
