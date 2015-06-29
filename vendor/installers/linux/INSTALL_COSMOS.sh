#!/usr/bin/env bash

cmdtoyum="yum update -y; yum install -y gcc gcc-c++ openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel git gstreamer-plugins-base-devel cmake freeglut freeglut-devel qt4 qt4-devel"

read -p "Install dependencies using Root/Sudo/No (Rsn): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]
then
  :
elif [[ $REPLY =~ ^[Ss]$ ]]
then
  sudo bash -c "$cmdtoyum"
else
  su -c "$cmdtoyum"
fi

read -p "Install ruby using rbenv (Yn): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]?$ ]]
then
  git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
  git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  export PATH="$HOME/.rbenv/bin:$PATH"
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc
  eval "$(rbenv init -)"
  CONFIGURE_OPTS="--enable-shared" rbenv install 2.2.2
  rbenv rehash
  rbenv global 2.2.2
  echo 'gem: --no-ri --no-rdoc' >> ~/.gemrc
fi

echo "Installing COSMOS gem"
gem install cosmos
rbenv rehash

read -p "Install and run COSMOS demo (Yn): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]?$ ]]
then
  cosmos demo ~/cosmosdemo
  ruby ~/cosmosdemo/tools/Launcher &
fi

