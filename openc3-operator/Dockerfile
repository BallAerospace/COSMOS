ARG OPENC3_REGISTRY=docker.io
ARG OPENC3_TAG=latest

FROM ${OPENC3_REGISTRY}/openc3/openc3-base:${OPENC3_TAG}

WORKDIR /openc3/lib/openc3/operators/

USER ${USER_ID}:${GROUP_ID}

CMD [ "ruby", "microservice_operator.rb"]
