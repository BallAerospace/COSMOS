# build stage
FROM ubuntu:20.04 as build-stage

# We require a local certificate file so set that up.
# You must place a valid cert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE /devel/cacert.pem
ENV CURL_CA_BUNDLE /devel/cacert.pem
ENV REQUESTS_CA_BUNDLE /devel/cacert.pem
ENV NODE_EXTRA_CA_CERTS /devel/cacert.pem

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update -y && apt-get install -y \
  --no-install-recommends \
  --option "Acquire:http::No-Cache=true" \
  --option "Acquire:http::Pipeline-Depth=0" \
  curl \
  git \
  netbase \
  nodejs \
  npm \
  libgtk2.0-0 \
  libnotify-dev \
  libgconf-2-4 \
  libnss3 \
  libxss1 \
  libasound2 \
  xvfb

RUN git config --global http.sslCAinfo /devel/cacert.pem

WORKDIR /app
COPY package*.json ./
RUN ["npm", "install"]
COPY . .
RUN ["npm", "run", "build"]

# production stage
FROM nginx:stable-alpine as production-stage
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY --from=build-stage /app/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
