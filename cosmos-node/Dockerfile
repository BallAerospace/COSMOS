FROM cosmos-ruby

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
  xvfb && \
  npm i -g npm