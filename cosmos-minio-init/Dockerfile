FROM minio/mc:RELEASE.2021-11-05T10-05-06Z

WORKDIR /cosmos/minio/

COPY ./* /cosmos/minio/

ENTRYPOINT ["/bin/sh"]

CMD [ "/cosmos/minio/init.sh" ]
