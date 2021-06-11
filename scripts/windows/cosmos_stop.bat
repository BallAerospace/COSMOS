REM Stop and remove all containers
docker stop cosmos-operator && docker container rm cosmos-operator
docker stop cosmos-traefik && docker container rm cosmos-traefik
docker stop cosmos-script-runner-api && docker container rm cosmos-script-runner-api
docker stop cosmos-cmd-tlm-api && docker container rm cosmos-cmd-tlm-api
docker stop cosmos-minio && docker container rm cosmos-minio
docker stop cosmos-redis && docker container rm cosmos-redis
