# This script install COSMOS C2 directly on a host instead of Docker
# Note: This is not a supported configuration. Official Releases are provided as Docker Containers

# Install extra needed packages
./cosmosc2_install_packages.sh

# Install Ruby
./cosmosc2_install_ruby.sh

# Install Redis
./cosmosc2_install_redis.sh

# Install Minio
./cosmosc2_install_minio.sh

# Install Traefik
./cosmosc2_install_traefik.sh

# Install COSMOS
./cosmosc2_install_cosmosc2.sh

# Start all the COSMOS Services
./cosmosc2_start_services.sh

# First Time Initialization
./cosmosc2_first_init.sh
