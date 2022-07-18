# WARNING: This Dockerfile is used as an easy way to develop running OPENC3 directly on a host
# To install on your host, use the openc3_install.sh script instead
# docker build -t openc3_centos7 . 
# docker run -it --rm --name openc3_centos7 -p 2900:2900 openc3_centos7

FROM centos:7

# We require a local certificate file so set that up.
# You must place a valid cacert.pem file in your OPENC3 development folder for this work
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
ENV IMAGE_USER=openc3
ENV IMAGE_GROUP=openc3
ENV USER_ID=1000
ENV GROUP_ID=1000
RUN /usr/sbin/groupadd -g ${GROUP_ID} ${IMAGE_GROUP}
RUN /usr/sbin/useradd -u ${USER_ID} -g ${IMAGE_GROUP} -g wheel -s /bin/ash ${IMAGE_USER}
RUN echo "openc3 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openc3

# Switch to user
USER ${USER_ID}:${GROUP_ID}
WORKDIR /home/openc3/

# Now do all the work you would do on a real host

# Act like a user who starts with pulling OPENC3 from git
RUN git clone https://github.com/OpenC3/openc3.git

# Install extra needed packages
COPY ./openc3_install_packages.sh /home/openc3/openc3/examples/hostinstall/centos7/.
RUN ./openc3/examples/hostinstall/centos7/openc3_install_packages.sh

# Install Ruby
COPY ./openc3_install_ruby.sh /home/openc3/openc3/examples/hostinstall/centos7/.
RUN ./openc3/examples/hostinstall/centos7/openc3_install_ruby.sh

# Install Redis
COPY ./openc3_install_redis.sh /home/openc3/openc3/examples/hostinstall/centos7/.
RUN ./openc3/examples/hostinstall/centos7/openc3_install_redis.sh

# Install Minio
COPY ./openc3_install_minio.sh /home/openc3/openc3/examples/hostinstall/centos7/.
RUN ./openc3/examples/hostinstall/centos7/openc3_install_minio.sh

# Install Traefik
COPY ./openc3_install_traefik.sh /home/openc3/openc3/examples/hostinstall/centos7/.
RUN ./openc3/examples/hostinstall/centos7/openc3_install_traefik.sh

# Install OPENC3
COPY ./openc3_install_openc3.sh /home/openc3/openc3/examples/hostinstall/centos7/.
RUN ./openc3/examples/hostinstall/centos7/openc3_install_openc3.sh

COPY ./openc3_start_services.sh /home/openc3/openc3/examples/hostinstall/centos7/.
COPY ./openc3_first_init.sh /home/openc3/openc3/examples/hostinstall/centos7/.
COPY ./docker_init.sh /home/openc3/openc3/examples/hostinstall/centos7/.
CMD [ "/home/openc3/openc3/examples/hostinstall/centos7/docker_init.sh" ]
