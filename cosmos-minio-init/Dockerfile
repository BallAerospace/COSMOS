ARG COSMOS_REGISTRY=docker.io

FROM ${COSMOS_REGISTRY}/minio/mc:RELEASE.2021-12-10T00-14-28Z

WORKDIR /cosmos/minio/

COPY ./* /cosmos/minio/

ENTRYPOINT ["/bin/sh"]

CMD [ "/cosmos/minio/init.sh" ]
