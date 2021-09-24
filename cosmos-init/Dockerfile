FROM ballaerospace/cosmosc2-base

USER root

RUN apk --update add curl \
  && curl https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc \
  && chmod +x /usr/bin/mc

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} minio /cosmos/minio/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} plugins /cosmos/plugins/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} init.sh /cosmos/

RUN cd /cosmos/plugins/cosmos-demo/ && rake build VERSION=5.0.0 --quiet

CMD [ "/cosmos/init.sh" ]
