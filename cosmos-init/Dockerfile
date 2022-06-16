ARG COSMOS_REGISTRY=docker.io
ARG COSMOS_TAG=latest

FROM ${COSMOS_REGISTRY}/minio/mc:RELEASE.2021-12-10T00-14-28Z AS minio-mc
FROM ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-node:${COSMOS_TAG} AS cosmos-frontend-tmp

WORKDIR /cosmos/plugins/

USER root

COPY ./plugins/*.json ./
COPY ./plugins/cosmosc2-tool-base/*.json cosmosc2-tool-base/
COPY ./plugins/packages/cosmosc2-tool-admin/*.json packages/cosmosc2-tool-admin/
COPY ./plugins/packages/cosmosc2-tool-autonomic/*.json packages/cosmosc2-tool-autonomic/
COPY ./plugins/packages/cosmosc2-tool-calendar/*.json packages/cosmosc2-tool-calendar/
COPY ./plugins/packages/cosmosc2-tool-cmdsender/*.json packages/cosmosc2-tool-cmdsender/
COPY ./plugins/packages/cosmosc2-tool-cmdtlmserver/*.json packages/cosmosc2-tool-cmdtlmserver/
COPY ./plugins/packages/cosmosc2-tool-dataextractor/*.json packages/cosmosc2-tool-dataextractor/
COPY ./plugins/packages/cosmosc2-tool-dataviewer/*.json packages/cosmosc2-tool-dataviewer/
COPY ./plugins/packages/cosmosc2-tool-handbooks/*.json packages/cosmosc2-tool-handbooks/
COPY ./plugins/packages/cosmosc2-tool-limitsmonitor/*.json packages/cosmosc2-tool-limitsmonitor/
COPY ./plugins/packages/cosmosc2-tool-packetviewer/*.json packages/cosmosc2-tool-packetviewer/
COPY ./plugins/packages/cosmosc2-tool-scriptrunner/*.json packages/cosmosc2-tool-scriptrunner/
COPY ./plugins/packages/cosmosc2-tool-tablemanager/*.json packages/cosmosc2-tool-tablemanager/
COPY ./plugins/packages/cosmosc2-tool-tlmgrapher/*.json packages/cosmosc2-tool-tlmgrapher/
COPY ./plugins/packages/cosmosc2-tool-tlmviewer/*.json packages/cosmosc2-tool-tlmviewer/
COPY ./plugins/packages/cosmosc2-tool-common/ packages/cosmosc2-tool-common/
COPY ./plugins/packages/cosmosc2-demo/*.json packages/cosmosc2-demo/

ARG NPM_URL
RUN yarn config set registry $NPM_URL && yarn --network-timeout 600000

COPY ./plugins/docker-package-build.sh ./plugins/docker-package-install.sh ./plugins/babel.config.js ./plugins/.eslintrc.js ./plugins/.nycrc ./
RUN chmod +x ./docker-package-build.sh ./docker-package-install.sh
COPY ./plugins/cosmosc2-tool-base/ cosmosc2-tool-base/
RUN ["/cosmos/plugins/docker-package-install.sh", "cosmosc2-tool-base"]

# Build admin tool
FROM cosmos-frontend-tmp AS cosmos-tmp1
COPY ./plugins/packages/cosmosc2-tool-admin/ packages/cosmosc2-tool-admin/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-admin"]

# Build cmdsender tool
COPY ./plugins/packages/cosmosc2-tool-cmdsender/ packages/cosmosc2-tool-cmdsender/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-cmdsender"]

# Build cmdtlmserver tool
COPY ./plugins/packages/cosmosc2-tool-cmdtlmserver/ packages/cosmosc2-tool-cmdtlmserver/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-cmdtlmserver"]

# Build dataextractor tool
FROM cosmos-frontend-tmp AS cosmos-tmp2
COPY ./plugins/packages/cosmosc2-tool-dataextractor/ packages/cosmosc2-tool-dataextractor/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-dataextractor"]

# Build dataviewer tool
COPY ./plugins/packages/cosmosc2-tool-dataviewer/ packages/cosmosc2-tool-dataviewer/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-dataviewer"]

# Build handbooks tool
COPY ./plugins/packages/cosmosc2-tool-handbooks/ packages/cosmosc2-tool-handbooks/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-handbooks"]

# Build limitsmonitor tool
COPY ./plugins/packages/cosmosc2-tool-limitsmonitor/ packages/cosmosc2-tool-limitsmonitor/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-limitsmonitor"]

# Build packetviewer tool
FROM cosmos-frontend-tmp AS cosmos-tmp3
COPY ./plugins/packages/cosmosc2-tool-packetviewer/ packages/cosmosc2-tool-packetviewer/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-packetviewer"]

# Build scriptrunner tool
COPY ./plugins/packages/cosmosc2-tool-scriptrunner/ packages/cosmosc2-tool-scriptrunner/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-scriptrunner"]

# Build calendar tool
COPY ./plugins/packages/cosmosc2-tool-calendar/ packages/cosmosc2-tool-calendar/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-calendar"]

# Build tablemanager tool
COPY ./plugins/packages/cosmosc2-tool-tablemanager/ packages/cosmosc2-tool-tablemanager/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-tablemanager"]

# Build tlmgrapher tool
FROM cosmos-frontend-tmp AS cosmos-tmp4
COPY ./plugins/packages/cosmosc2-tool-tlmgrapher/ packages/cosmosc2-tool-tlmgrapher/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-tlmgrapher"]

# Build tlmviewer tool
COPY ./plugins/packages/cosmosc2-tool-tlmviewer/ packages/cosmosc2-tool-tlmviewer
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-tlmviewer"]

# Build autonomic tool
COPY ./plugins/packages/cosmosc2-tool-autonomic/ packages/cosmosc2-tool-autonomic/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-autonomic"]

# Build demo config
COPY ./plugins/packages/cosmosc2-demo/ packages/cosmosc2-demo/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-demo"]

FROM cosmos-frontend-tmp AS cosmos-frontend-base-tmp

COPY --from=cosmos-tmp1 /cosmos/plugins/gems/* /cosmos/plugins/gems/
COPY --from=cosmos-tmp2 /cosmos/plugins/gems/* /cosmos/plugins/gems/
COPY --from=cosmos-tmp3 /cosmos/plugins/gems/* /cosmos/plugins/gems/
COPY --from=cosmos-tmp4 /cosmos/plugins/gems/* /cosmos/plugins/gems/

FROM ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-base:${COSMOS_TAG}

COPY --from=cosmos-frontend-base-tmp --chown=${IMAGE_USER}:${IMAGE_GROUP} /cosmos/plugins/gems/* /cosmos/plugins/gems/
COPY --from=cosmos-frontend-base-tmp --chown=${IMAGE_USER}:${IMAGE_GROUP} /cosmos/plugins/yarn.lock /cosmos/plugins/yarn.lock
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./init.sh /cosmos/

COPY --from=minio-mc /bin/mc /bin/mc
COPY ./script-runner.json /cosmos/minio/script-runner.json

CMD [ "/cosmos/init.sh" ]
