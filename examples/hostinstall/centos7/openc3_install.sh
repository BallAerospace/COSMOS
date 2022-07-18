# This script install OpenC3 directly on a host instead of Docker
# Note: This is not a supported configuration. Official Releases are provided as Docker Containers

# Install extra needed packages
./openc3_install_packages.sh

# Install Ruby
./openc3_install_ruby.sh

# Install Redis
./openc3_install_redis.sh

# Install Minio
./openc3_install_minio.sh

# Install Traefik
./openc3_install_traefik.sh

# Install OpenC3
./openc3_install_openc3.sh

# Start all the OpenC3 Services
./openc3_start_services.sh

# First Time Initialization
./openc3_first_init.sh
