FROM cosmos-base

WORKDIR /cosmos/lib/cosmos/operators/

ENV COSMOS_REDIS_URL=redis://cosmos-redis:6379
ENV COSMOS_REDIS_HOST=cosmos-redis:6379
ENV COSMOS_REDIS_USERNAME=cosmos
ENV COSMOS_REDIS_PASSWORD=cosmospassword

CMD [ "ruby", "microservice_operator.rb"]
