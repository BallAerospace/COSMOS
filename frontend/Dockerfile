FROM cosmos-base

ENV NODE_EXTRA_CA_CERTS=/devel/cacert.pem
# ARG rather than ENV so it doesn't persist in the build image
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && apt-get install -y \
  --no-install-recommends \
  --option "Acquire:http::No-Cache=true" \
  --option "Acquire:http::Pipeline-Depth=0" \
  nodejs \
  npm \
  libgtk2.0-0 \
  libnotify-dev \
  libgconf-2-4 \
  libnss3 \
  libxss1 \
  libasound2 \
  xvfb

RUN mkdir -p /cosmos/plugins
WORKDIR /cosmos/plugins/
COPY . .

RUN npm install --global lerna
RUN lerna bootstrap --hoist

WORKDIR /cosmos/plugins/cosmosc2-tool-base/
RUN npm install && npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-admin/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-cmdsender/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-cmdtlmserver/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-dataextractor/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-dataviewer/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-limitsmonitor/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-packetviewer/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-scriptrunner/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-tlmgrapher/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/packages/cosmosc2-tool-tlmviewer/
RUN npm run build
RUN rake build VERSION=5.0.0

WORKDIR /cosmos/plugins/
COPY init.sh .
CMD [ "/cosmos/plugins/init.sh" ]
