@echo on
REM Please see cosmos_setup.bat

REM These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144" || exit /b

docker network inspect cosmos || docker network create cosmos || exit /b

docker container rm cosmos-redis
docker volume create cosmos-redis-v || exit /b
docker run --network cosmos -p 127.0.0.1:6379:6379 -d --name cosmos-redis -v cosmos-redis-v:/data redis:6.2 redis-server --appendonly yes || exit /b

docker container rm cosmos-minio
docker volume create cosmos-minio-v || exit /b
docker run --network cosmos -p 127.0.0.1:9000:9000 -d --name cosmos-minio -v cosmos-minio-v:/data minio/minio:RELEASE.2020-08-25T00-21-20Z server /data || exit /b
timeout 30 >nul

docker container rm cosmos-cmd-tlm-api
docker run --network cosmos -p 127.0.0.1:2901:2901 -d --name cosmos-cmd-tlm-api cosmos-cmd-tlm-api || exit /b

docker container rm cosmos-script-runner-api
docker run --network cosmos -p 127.0.0.1:2902:2902 -d --name cosmos-script-runner-api cosmos-script-runner-api || exit /b

docker container rm cosmos-operator
docker run --network cosmos -d --name cosmos-operator cosmos-operator || exit /b

docker container rm cosmos-traefik
docker run --network cosmos -p 127.0.0.1:2900:80 -d --name cosmos-traefik cosmos-traefik || exit /b

docker run --network cosmos --name cosmos-frontend-init --rm cosmos-frontend-init || exit /b
docker run --network cosmos --name cosmos-init --rm cosmos-init || exit /b

REM If everything is working you should be able to access Cosmos at http://localhost:2900/
