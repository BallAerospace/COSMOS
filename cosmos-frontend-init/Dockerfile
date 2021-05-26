FROM cosmos-node AS cosmos-frontend-tmp

WORKDIR /cosmos/plugins/

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
COPY ./packages/cosmosc2-tool-tlmgrapher/*.json packages/cosmosc2-tool-tlmgrapher/
COPY ./packages/cosmosc2-tool-tlmviewer/*.json packages/cosmosc2-tool-tlmviewer/

# This is a fix for a network issue with registry.yarnpkg.com, possibly caused by the Ball firewall.
# Might resolve itself and allow this line to be removed in the future...
RUN yarn config set registry "https://registry.npmjs.org"

RUN yarn

COPY . .

RUN sh docker-build.sh

FROM cosmos-base

COPY --from=cosmos-frontend-tmp /cosmos/plugins/init.sh /cosmos/plugins/init.sh
COPY --from=cosmos-frontend-tmp /cosmos/plugins/gems/* /cosmos/plugins/gems/

CMD [ "/cosmos/plugins/init.sh" ]
