FROM redis:6.2

RUN mkdir /config
COPY ./config/* /config/

CMD [ "redis-server", "/config/redis.conf" ]
