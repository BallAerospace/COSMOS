#!/bin/sh
set -eux

sudo yum update -y && sudo yum install -y \
  gcc \
  gcc-c++ \
  gdbm-devel \
  iproute \
  libyaml-devel \
  libffi-devel \
  make \
  ncurses-devel \
  net-tools \
  nc \
  openssl-devel \
  readline-devel \
  wget \
  zlib-devel
