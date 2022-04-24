# WARNING: This Dockerfile is used as an easy way to develop running COSMOS directly on a host
# To install on your host, use the cosmosc2_install.sh script instead
# docker build -t cosmosc2_centos7 . 
# docker run -it --rm --name cosmosc2_centos7 -p 2900:2900 cosmosc2_centos7

FROM centos:7

# We require a local certificate file so set that up.
# You must place a valid cacert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem

# Base packages so we can create a sudo user
RUN yum update -y && yum install -y \
  git \
  shadow-utils \
  sudo 

# Set user and group
ENV IMAGE_USER=cosmos
ENV IMAGE_GROUP=cosmos
ENV USER_ID=1000
ENV GROUP_ID=1000
RUN /usr/sbin/groupadd -g ${GROUP_ID} ${IMAGE_GROUP}
RUN /usr/sbin/useradd -u ${USER_ID} -g ${IMAGE_GROUP} -g wheel -s /bin/ash ${IMAGE_USER}
RUN echo "cosmos  ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/cosmos

# Switch to user
USER ${USER_ID}:${GROUP_ID}
WORKDIR /home/cosmos/

# Now do all the work you would do on a real host

# Act like a user who starts with pulling COSMOS from git
RUN git clone https://github.com/BallAerospace/COSMOS.git

# Install extra needed packages
COPY ./cosmosc2_install_packages.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
RUN ./COSMOS/examples/hostinstall/centos7/cosmosc2_install_packages.sh

# Install Ruby
COPY ./cosmosc2_install_ruby.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
RUN ./COSMOS/examples/hostinstall/centos7/cosmosc2_install_ruby.sh

# Install Redis
COPY ./cosmosc2_install_redis.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
RUN ./COSMOS/examples/hostinstall/centos7/cosmosc2_install_redis.sh

# Install Minio
COPY ./cosmosc2_install_minio.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
RUN ./COSMOS/examples/hostinstall/centos7/cosmosc2_install_minio.sh

# Install Traefik
COPY ./cosmosc2_install_traefik.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
RUN ./COSMOS/examples/hostinstall/centos7/cosmosc2_install_traefik.sh

# Install COSMOS
COPY ./cosmosc2_install_cosmosc2.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
RUN ./COSMOS/examples/hostinstall/centos7/cosmosc2_install_cosmosc2.sh

COPY ./cosmosc2_start_services.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
COPY ./cosmosc2_first_init.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
COPY ./docker_init.sh /home/cosmos/COSMOS/examples/hostinstall/centos7/.
CMD [ "/home/cosmos/COSMOS/examples/hostinstall/centos7/docker_init.sh" ]
