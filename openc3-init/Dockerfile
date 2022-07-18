ARG OPENC3_REGISTRY=docker.io
ARG OPENC3_TAG=latest

FROM ${OPENC3_REGISTRY}/minio/mc:RELEASE.2021-12-10T00-14-28Z AS minio-mc
FROM ${OPENC3_REGISTRY}/openc3/openc3-node:${OPENC3_TAG} AS openc3-frontend-tmp

WORKDIR /openc3/plugins/

USER root

COPY ./plugins/*.json ./
COPY ./plugins/openc3-tool-base/*.json openc3-tool-base/
COPY ./plugins/packages/openc3-tool-admin/*.json packages/openc3-tool-admin/
COPY ./plugins/packages/openc3-tool-autonomic/*.json packages/openc3-tool-autonomic/
COPY ./plugins/packages/openc3-tool-calendar/*.json packages/openc3-tool-calendar/
COPY ./plugins/packages/openc3-tool-cmdsender/*.json packages/openc3-tool-cmdsender/
COPY ./plugins/packages/openc3-tool-cmdtlmserver/*.json packages/openc3-tool-cmdtlmserver/
COPY ./plugins/packages/openc3-tool-dataextractor/*.json packages/openc3-tool-dataextractor/
COPY ./plugins/packages/openc3-tool-dataviewer/*.json packages/openc3-tool-dataviewer/
COPY ./plugins/packages/openc3-tool-handbooks/*.json packages/openc3-tool-handbooks/
COPY ./plugins/packages/openc3-tool-limitsmonitor/*.json packages/openc3-tool-limitsmonitor/
COPY ./plugins/packages/openc3-tool-packetviewer/*.json packages/openc3-tool-packetviewer/
COPY ./plugins/packages/openc3-tool-scriptrunner/*.json packages/openc3-tool-scriptrunner/
COPY ./plugins/packages/openc3-tool-tablemanager/*.json packages/openc3-tool-tablemanager/
COPY ./plugins/packages/openc3-tool-tlmgrapher/*.json packages/openc3-tool-tlmgrapher/
COPY ./plugins/packages/openc3-tool-tlmviewer/*.json packages/openc3-tool-tlmviewer/
COPY ./plugins/packages/openc3-tool-common/ packages/openc3-tool-common/
COPY ./plugins/packages/openc3-demo/*.json packages/openc3-demo/

ARG NPM_URL
RUN yarn config set registry $NPM_URL && yarn --network-timeout 600000

COPY ./plugins/docker-package-build.sh ./plugins/docker-package-install.sh ./plugins/babel.config.js ./plugins/.eslintrc.js ./plugins/.nycrc ./
RUN chmod +x ./docker-package-build.sh ./docker-package-install.sh
COPY ./plugins/openc3-tool-base/ openc3-tool-base/
RUN ["/openc3/plugins/docker-package-install.sh", "openc3-tool-base"]

# Build admin tool
FROM openc3-frontend-tmp AS openc3-tmp1
COPY ./plugins/packages/openc3-tool-admin/ packages/openc3-tool-admin/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-admin"]

# Build cmdsender tool
COPY ./plugins/packages/openc3-tool-cmdsender/ packages/openc3-tool-cmdsender/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-cmdsender"]

# Build cmdtlmserver tool
COPY ./plugins/packages/openc3-tool-cmdtlmserver/ packages/openc3-tool-cmdtlmserver/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-cmdtlmserver"]

# Build dataextractor tool
FROM openc3-frontend-tmp AS openc3-tmp2
COPY ./plugins/packages/openc3-tool-dataextractor/ packages/openc3-tool-dataextractor/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-dataextractor"]

# Build dataviewer tool
COPY ./plugins/packages/openc3-tool-dataviewer/ packages/openc3-tool-dataviewer/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-dataviewer"]

# Build handbooks tool
COPY ./plugins/packages/openc3-tool-handbooks/ packages/openc3-tool-handbooks/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-handbooks"]

# Build limitsmonitor tool
COPY ./plugins/packages/openc3-tool-limitsmonitor/ packages/openc3-tool-limitsmonitor/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-limitsmonitor"]

# Build packetviewer tool
FROM openc3-frontend-tmp AS openc3-tmp3
COPY ./plugins/packages/openc3-tool-packetviewer/ packages/openc3-tool-packetviewer/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-packetviewer"]

# Build scriptrunner tool
COPY ./plugins/packages/openc3-tool-scriptrunner/ packages/openc3-tool-scriptrunner/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-scriptrunner"]

# Build calendar tool
COPY ./plugins/packages/openc3-tool-calendar/ packages/openc3-tool-calendar/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-calendar"]

# Build tablemanager tool
COPY ./plugins/packages/openc3-tool-tablemanager/ packages/openc3-tool-tablemanager/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-tablemanager"]

# Build tlmgrapher tool
FROM openc3-frontend-tmp AS openc3-tmp4
COPY ./plugins/packages/openc3-tool-tlmgrapher/ packages/openc3-tool-tlmgrapher/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-tlmgrapher"]

# Build tlmviewer tool
COPY ./plugins/packages/openc3-tool-tlmviewer/ packages/openc3-tool-tlmviewer
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-tlmviewer"]

# Build autonomic tool
COPY ./plugins/packages/openc3-tool-autonomic/ packages/openc3-tool-autonomic/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-tool-autonomic"]

# Build demo config
COPY ./plugins/packages/openc3-demo/ packages/openc3-demo/
RUN ["/openc3/plugins/docker-package-build.sh", "openc3-demo"]

FROM openc3-frontend-tmp AS openc3-frontend-base-tmp

COPY --from=openc3-tmp1 /openc3/plugins/gems/* /openc3/plugins/gems/
COPY --from=openc3-tmp2 /openc3/plugins/gems/* /openc3/plugins/gems/
COPY --from=openc3-tmp3 /openc3/plugins/gems/* /openc3/plugins/gems/
COPY --from=openc3-tmp4 /openc3/plugins/gems/* /openc3/plugins/gems/

FROM ${OPENC3_REGISTRY}/openc3/openc3-base:${OPENC3_TAG}

COPY --from=openc3-frontend-base-tmp --chown=${IMAGE_USER}:${IMAGE_GROUP} /openc3/plugins/gems/* /openc3/plugins/gems/
COPY --from=openc3-frontend-base-tmp --chown=${IMAGE_USER}:${IMAGE_GROUP} /openc3/plugins/yarn.lock /openc3/plugins/yarn.lock
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./init.sh /openc3/

COPY --from=minio-mc /bin/mc /bin/mc
COPY ./script-runner.json /openc3/minio/script-runner.json

CMD [ "/openc3/init.sh" ]
