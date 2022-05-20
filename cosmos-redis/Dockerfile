ARG COSMOS_REGISTRY=docker.io

FROM ${COSMOS_REGISTRY}/redis:6.2

RUN mkdir /config
COPY ./config/* /config/

EXPOSE 3680

CMD [ "redis-server", "/config/redis.conf" ]
