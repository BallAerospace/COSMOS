#!/usr/bin/env bash

expand_tilde()
{
  case "$1" in
  (\~)        echo "$HOME";;
  (\~/*)      echo "$HOME/${1#\~/}";;
  (\~[^/]*/*) local user=$(eval echo ${1%%/*})
              echo "$user/${1#*/}";;
  (\~[^/]*)   eval echo ${1};;
  (*)         echo "$1";;
  esac
}

read -p "Enter COSMOS Configuration Directory [~/cosmos-demo]: " cosmos_install
cosmos_install=${cosmos_install:="$HOME/cosmos-demo"}
cosmos_install=$(expand_tilde "$cosmos_install")

if [[ -d "$cosmos_install" ]]; then
  echo "ERROR: Installation folder already exists: $cosmos_install"
  exit 1
else
  # Create the installation folder
  mkdir "$cosmos_install"
fi

# Copy the template to the new directory
cp -r cosmos-init/plugins/plugin-template/* "$cosmos_install"
# Rename the gemspec after the directory name
cd $cosmos_install
base=$(basename "$cosmos_install")
mv plugin-template.gemspec $base.gemspec
sed -i "s/TEMPLATE/$base/g" $base.gemspec
