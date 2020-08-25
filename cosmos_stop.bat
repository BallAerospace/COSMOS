docker stop cosmos_operator
docker container rm cosmos_operator
docker stop cosmos_frontend
docker container rm cosmos_frontend
docker stop cosmos_script_runner_api
docker container rm cosmos_script_runner_api
docker stop cosmos_cmd_tlm_api
docker container rm cosmos_cmd_tlm_api
docker stop cosmos_minio
docker container rm cosmos_minio
docker stop cosmos_redis
docker container rm cosmos_redis
docker stop cosmos_fluentd
docker container rm cosmos_fluentd
docker stop cosmos_kibana
docker container rm cosmos_kibana
docker stop cosmos_elasticsearch
docker container rm cosmos_elasticsearch
docker network rm cosmos