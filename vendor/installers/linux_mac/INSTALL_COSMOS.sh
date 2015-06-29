#!/usr/bin/env bash

# Mac Install
if [[ "$OSTYPE" == "darwin"* ]]; then

  # Disable App Nap
  defaults write -g NSAppSleepDisabled -bool true

  # Install Homebrew
  if hash brew 2>/dev/null; then
    :
  else
    echo "Installing Homebrew - You may need to enter your password and install xcode tools"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"  
  fi

  # Install necessary packages
  echo "Installing Homebrew packages"
  brew update
  brew install libksba cmake qt rbenv ruby-build openssl libyaml libffi
  
  # Configure rbenv
  echo 'if hash rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bash_profile
  source ~/.bash_profile

  # Install Ruby
  echo "Installing Ruby"
  CC=clang CONFIGURE_OPTS="--with-gcc=clang --enable-shared" rbenv install 2.2.2
  rbenv rehash
  rbenv global 2.2.2
  echo 'gem: --no-ri --no-rdoc' >> ~/.gemrc

  # Install COSMOS
  echo "Installing COSMOS gem"
  gem install cosmos
  rbenv rehash

  # Install COSMOS Demo
  read -p "Install and run COSMOS demo (Yn): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]?$ ]]
  then
    echo "Install COSMOS Demo - If successful COSMOS should launch"
    cosmos demo ~/cosmosdemo
    open ~/cosmosdemo/tools/mac/Launcher.app
  fi
  
else # Linux

  # Yum dependencies tested on Centos 6.5/6.6/7
  cmdtoyum="yum update -y; yum install -y gcc gcc-c++ openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel git gstreamer-plugins-base-devel cmake freeglut freeglut-devel qt4 qt4-devel"

  # Install dependencies
  read -p "Install dependencies using Root/Sudo/No (Rsn): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Nn]$ ]]
  then
    :
  elif [[ $REPLY =~ ^[Ss]$ ]]
  then
    if hash yum 2>/dev/null; then  
      sudo bash -c "$cmdtoyum"
    fi
  else
    if hash yum 2>/dev/null; then   
      su -c "$cmdtoyum"
    fi
  fi
  
  # Install ruby
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

  # Install COSMOS
  echo "Installing COSMOS gem"
  gem install cosmos
  rbenv rehash

  # Install demo
  read -p "Install and run COSMOS demo (Yn): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]?$ ]]
  then
    cosmos demo ~/cosmosdemo
    ruby ~/cosmosdemo/tools/Launcher &
  fi
  
fi # OS check
