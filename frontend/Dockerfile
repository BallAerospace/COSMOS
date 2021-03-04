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

RUN mkdir -p /cosmos/plugins/cosmos-tool-base
WORKDIR /cosmos/plugins/cosmos-tool-base/
COPY cosmos-tool-base/. .
RUN npm install && npm run build
RUN bundle exec rake build VERSION=5.0.0 --quiet && \
  bundle config set --local without 'development' && \
  bundle install --quiet

WORKDIR /cosmos/plugins/
COPY init.sh .
CMD [ "/cosmos/plugins/init.sh" ]
