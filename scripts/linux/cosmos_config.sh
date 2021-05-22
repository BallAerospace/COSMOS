#!/usr/bin/env bash

read -p "Enter COSMOS Configuration Directory [~/cosmos-demo]: " cosmos_install
echo "$cosmos_install"
if [[ -d "$cosmos_install" ]]; then
  echo "ERROR: Installation folder already exists: $cosmos_install"
  exit 1
else
  # Create the installation folder
  mkdir "$cosmos_install"
fi

# Copy the template to the new directory
cp -r ../../cosmos-init/plugins/plugin-template/* "$cosmos_install"
# Rename the gemspec after the directory name
cd $cosmos_install
base = basename $cosmos_install
mv plugin-template.gemspec $base.gemspec
