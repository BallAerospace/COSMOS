ARG COSMOS_REGISTRY=docker.io
ARG COSMOS_TAG=latest

FROM ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-base:${COSMOS_TAG}

WORKDIR /cosmos/lib/cosmos/operators/

USER ${USER_ID}:${GROUP_ID}

CMD [ "ruby", "microservice_operator.rb"]
