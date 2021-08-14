FROM ballaerospace/cosmosc2-node AS cosmos-frontend-tmp

WORKDIR /cosmos/plugins/

USER root

COPY ./*.json ./
COPY ./cosmosc2-tool-base/*.json cosmosc2-tool-base/
COPY ./packages/cosmosc2-tool-admin/*.json packages/cosmosc2-tool-admin/
COPY ./packages/cosmosc2-tool-cmdsender/*.json packages/cosmosc2-tool-cmdsender/
COPY ./packages/cosmosc2-tool-cmdtlmserver/*.json packages/cosmosc2-tool-cmdtlmserver/
COPY ./packages/cosmosc2-tool-common/*.json packages/cosmosc2-tool-common/
COPY ./packages/cosmosc2-tool-dataextractor/*.json packages/cosmosc2-tool-dataextractor/
COPY ./packages/cosmosc2-tool-dataviewer/*.json packages/cosmosc2-tool-dataviewer/
COPY ./packages/cosmosc2-tool-limitsmonitor/*.json packages/cosmosc2-tool-limitsmonitor/
COPY ./packages/cosmosc2-tool-packetviewer/*.json packages/cosmosc2-tool-packetviewer/
COPY ./packages/cosmosc2-tool-scriptrunner/*.json packages/cosmosc2-tool-scriptrunner/
COPY ./packages/cosmosc2-tool-timeline/*.json packages/cosmosc2-tool-timeline/
COPY ./packages/cosmosc2-tool-tlmgrapher/*.json packages/cosmosc2-tool-tlmgrapher/
COPY ./packages/cosmosc2-tool-tlmviewer/*.json packages/cosmosc2-tool-tlmviewer/

# This is a fix for a network issue with registry.yarnpkg.com, possibly caused by the Ball firewall.
# Might resolve itself and allow this line to be removed in the future...
RUN yarn config set registry "https://registry.npmjs.org"

RUN yarn

COPY ./docker-package-build.sh ./docker-package-install.sh ./babel.config.js ./.eslintrc.js ./.nycrc ./
RUN chmod +x ./docker-package-build.sh ./docker-package-install.sh
COPY ./cosmosc2-tool-base/ cosmosc2-tool-base/
COPY ./packages/cosmosc2-tool-common/ packages/cosmosc2-tool-common/
RUN ["/cosmos/plugins/docker-package-install.sh", "cosmosc2-tool-base"]

# Build admin tool
FROM cosmos-frontend-tmp AS cosmos-tmp1
COPY ./packages/cosmosc2-tool-admin/ packages/cosmosc2-tool-admin/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-admin"]

# Build cmdsender tool
COPY ./packages/cosmosc2-tool-cmdsender/ packages/cosmosc2-tool-cmdsender/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-cmdsender"]

# Build cmdtlmserver tool
COPY ./packages/cosmosc2-tool-cmdtlmserver/ packages/cosmosc2-tool-cmdtlmserver/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-cmdtlmserver"]

# Build dataextractor tool
FROM cosmos-frontend-tmp AS cosmos-tmp2
COPY ./packages/cosmosc2-tool-dataextractor/ packages/cosmosc2-tool-dataextractor/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-dataextractor"]

# Build dataviewer tool
COPY ./packages/cosmosc2-tool-dataviewer/ packages/cosmosc2-tool-dataviewer/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-dataviewer"]

# Build limitsmonitor tool
COPY ./packages/cosmosc2-tool-limitsmonitor/ packages/cosmosc2-tool-limitsmonitor/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-limitsmonitor"]

# Build packetviewer tool
FROM cosmos-frontend-tmp AS cosmos-tmp3
COPY ./packages/cosmosc2-tool-packetviewer/ packages/cosmosc2-tool-packetviewer/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-packetviewer"]

# Build scriptrunner tool
COPY ./packages/cosmosc2-tool-scriptrunner/ packages/cosmosc2-tool-scriptrunner/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-scriptrunner"]

# Build timeline tool
COPY ./packages/cosmosc2-tool-timeline/ packages/cosmosc2-tool-timeline/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-timeline"]

# Build tlmgrapher tool
FROM cosmos-frontend-tmp AS cosmos-tmp4
COPY ./packages/cosmosc2-tool-tlmgrapher/ packages/cosmosc2-tool-tlmgrapher/
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-tlmgrapher"]

# Build tlmviewer tool
COPY ./packages/cosmosc2-tool-tlmviewer/ packages/cosmosc2-tool-tlmviewer
RUN ["/cosmos/plugins/docker-package-build.sh", "cosmosc2-tool-tlmviewer"]


FROM cosmos-frontend-tmp AS cosmos-frontend-base-tmp

COPY --from=cosmos-tmp1 /cosmos/plugins/gems/* /cosmos/plugins/gems/
COPY --from=cosmos-tmp2 /cosmos/plugins/gems/* /cosmos/plugins/gems/
COPY --from=cosmos-tmp3 /cosmos/plugins/gems/* /cosmos/plugins/gems/
COPY --from=cosmos-tmp4 /cosmos/plugins/gems/* /cosmos/plugins/gems/

FROM ballaerospace/cosmosc2-base

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./init.sh /cosmos/plugins/init.sh
COPY --from=cosmos-frontend-base-tmp --chown=${IMAGE_USER}:${IMAGE_GROUP} /cosmos/plugins/gems/* /cosmos/plugins/gems/

CMD [ "/cosmos/plugins/init.sh" ]
