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
  brew tap cartr/qt4
  brew tap-pin cartr/qt4
  brew install qt@4
  brew install libksba cmake rbenv ruby-build openssl libyaml libffi

  # Configure rbenv
  echo 'if hash rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bash_profile
  source ~/.bash_profile

  # Install Ruby
  echo "Installing Ruby"
  CC=clang CONFIGURE_OPTS="--with-gcc=clang --enable-shared" rbenv install 2.5.6
  rbenv rehash
  rbenv global 2.5.6
  echo 'gem: --no-ri --no-rdoc' >> ~/.gemrc

  # Install COSMOS
  echo "Installing COSMOS gem"
  gem install cosmos --no-rdoc --no-ri
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
  cmdtoyum="yum update -y; yum install -y gcc; yum install -y gcc-c++; yum install -y openssl-devel; yum install -y libyaml-devel; yum install -y libffi-devel; yum install -y readline-devel; yum install -y zlib-devel; yum install -y gdbm-devel; yum install -y ncurses-devel; yum install -y git; yum install -y gstreamer-plugins-base-devel; yum install -y cmake; yum install -y freeglut; yum install -y freeglut-devel; yum install -y qt4; yum install -y qt4-devel;"

  #apt dependencies - lightly tested on Ubuntu 14.04 LTS
  cmdtoapt="apt-get update -y; apt-get install -y gcc; apt-get install -y g++; apt-get install -y libssl-dev; apt-get install -y libyaml-dev; apt-get install -y libffi-dev; apt-get install -y libreadline6-dev; apt-get install -y zlib1g-dev; apt-get install -y libgdbm3; apt-get install -y libgdbm-dev; apt-get install -y libncurses5-dev; apt-get install -y git; apt-get install -y libgstreamer0.10-dev; apt-get install -y libgstreamer-plugins-base0.10-dev; apt-get install -y cmake; apt-get install -y freeglut3; apt-get install -y freeglut3-dev; apt-get install -y qt4-default; apt-get install -y qt4-dev-tools; apt-get install -y libsmokeqt4-dev;"
  YUM_CMD=$(which yum)
  APT_GET_CMD=$(which apt-get)


  # Install dependencies
  read -p "Install dependencies using Root/Sudo/No (Rsn): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Nn]$ ]]
  then
    :
  elif [[ $REPLY =~ ^[Ss]$ ]]
  then
   if [[ ! -z $YUM_CMD ]]; then
    sudo bash -c "$cmdtoyum"
   elif [[ ! -z $APT_GET_CMD ]]; then
    sudo bash -c "$cmdtoapt"
   else
    echo "error can't figure out what package manager is being used"
    exit 1;
   fi
  else
   if [[ ! -z $YUM_CMD ]]; then
    su -c "$cmdtoyum"
   elif [[ ! -z $APT_GET_CMD ]]; then
    su -c "$cmdtoapt"
   else
    echo "error can't figure out what package manager is being used"
    exit 1;
   fi
fi


  # Install ruby
  read -p "Install ruby using rbenv (Yn): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]?$ ]]
  then
    if [ -d $HOME/.rbenv ]; then
      read -p ".rbenv folder already exists. Delete for clean install? (Yn): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]?$ ]]; then
        rm -rf ~/.rbenv
      fi
    fi

    if [ ! -d $HOME/.rbenv ]; then
      git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
      git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    else
      echo ".rbenv folder exists. Skipping git clone..."
    fi
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    eval "$(rbenv init -)"
    CONFIGURE_OPTS="--enable-shared" rbenv install 2.5.6
    rbenv rehash
    rbenv global 2.5.6
    echo 'gem: --no-ri --no-rdoc' >> ~/.gemrc
  fi

  # Install COSMOS
  echo "Installing COSMOS gem"
  gem install cosmos --no-rdoc --no-ri
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
