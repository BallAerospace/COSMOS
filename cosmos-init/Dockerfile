FROM ballaerospace/cosmosc2-base

USER root

COPY ./mc_20210902 /usr/bin/mc
RUN chmod +x /usr/bin/mc

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./minio /cosmos/minio/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./plugins /cosmos/plugins/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./init.sh /cosmos/

CMD [ "/cosmos/init.sh" ]
