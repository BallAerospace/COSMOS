FROM ballaerospace/cosmosc2-ruby AS cosmos-mc

USER root

RUN apk --update add curl \
  && curl https://dl.min.io/client/mc/release/linux-amd64/mc -o /tmp/mc

USER ${USER_ID}:${GROUP_ID}

FROM ballaerospace/cosmosc2-base

USER root

COPY --from=cosmos-mc /tmp/mc /usr/bin/mc
RUN chmod +x /usr/bin/mc

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./minio /cosmos/minio/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./plugins /cosmos/plugins/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./init.sh /cosmos/

CMD [ "/cosmos/init.sh" ]
