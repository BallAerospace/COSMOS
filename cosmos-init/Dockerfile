FROM ballaerospace/cosmosc2-base

RUN apk --update add curl \
  && curl https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc \
  && chmod +x /usr/bin/mc

COPY minio /cosmos/minio/
COPY plugins /cosmos/plugins/
COPY init.sh /cosmos/

CMD [ "/cosmos/init.sh" ]
