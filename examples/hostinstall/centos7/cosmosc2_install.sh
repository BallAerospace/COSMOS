# This script install COSMOS C2 directly on a host instead of Docker
# Note: This is not a supported configuration. Official Releases are provided as Docker Containers

# Pull the latest COSMOS from Github
git clone https://github.com/BallAerospace/COSMOS.git

# Install extra needed packages
./COSMOS/examples/hostinstall/centos7/cosmosc2_install_packages.sh

# Install Ruby
./COSMOS/examples/hostinstall/centos7/cosmosc2_install_ruby.sh

# Install Redis
./COSMOS/examples/hostinstall/centos7/cosmosc2_install_redis.sh

# Install Minio
./COSMOS/examples/hostinstall/centos7/cosmosc2_install_minio.sh

# Install Traefik
./COSMOS/examples/hostinstall/centos7/cosmosc2_install_traefik.sh

# Install COSMOS
./COSMOS/examples/hostinstall/centos7/cosmosc2_install_cosmosc2.sh

# Start all the COSMOS Services
./COSMOS/examples/hostinstall/centos7/cosmosc2_start_services.sh

# First Time Initialization
./COSMOS/examples/hostinstall/centos7/cosmosc2_first_init.sh
