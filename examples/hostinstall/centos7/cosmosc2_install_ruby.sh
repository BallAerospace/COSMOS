#!/bin/sh
set -eux

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
source ./cosmosc2_env.sh

sed -i "s|RUBYGEMS_URL|${RUBYGEMS_URL}|g" .gemrc
cp .gemrc ~/.

# Only ruby 2.0 in Centos7 so build from source

# START MODIFIED CONTENT FROM OFFICIAL RUBY DOCKERFILE

export LANG=C.UTF-8
export RUBY_MAJOR=3.0
export RUBY_VERSION=3.0.3
export RUBY_DOWNLOAD_SHA256=88cc7f0f021f15c4cd62b1f922e3a401697f7943551fe45b1fdf4f2417a17a9c

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built

wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"
echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict;
sudo mkdir -p /usr/src/ruby
sudo tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1
rm ruby.tar.xz;

# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
{ \
	echo '#define ENABLE_PATH_CHECK 0'; \
	echo; \
	cat /usr/src/ruby/file.c; \
} > file.c.new;
sudo mv file.c.new /usr/src/ruby/file.c

cd /usr/src/ruby;

sudo ./configure --disable-install-doc --enable-shared --prefix=/usr

sudo make -j "$(nproc)"
sudo make install

cd /
sudo rm -r /usr/src/ruby

# rough smoke test
ruby --version
gem --version
bundle --version

sudo gem update --system 3.3.5
sudo gem install bundler
sudo gem install rake
sudo bundle config build.nokogiri --use-system-libraries
sudo bundle config git.allow_insecure true

# END CONTENT FROM OFFICIAL RUBY DOCKERFILE
