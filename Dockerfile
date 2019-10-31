FROM ubuntu:18.04

RUN apt update
RUN apt install -y gcc g++ libssl-dev libyaml-dev libffi-dev libreadline6-dev zlib1g-dev libgdbm5 libgdbm-dev libncurses5-dev git libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev cmake freeglut3 freeglut3-dev qt4-default qt4-dev-tools libsmokeqt4-dev

RUN apt install -y ruby2.5 ruby2.5-dev
RUN gem install rake --no-rdoc --no-ri
RUN gem install cosmos --no-rdoc --no-ri
RUN cosmos demo ~/cosmosdemo
