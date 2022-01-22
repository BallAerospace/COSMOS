FROM docker

# We require a local certificate file so set that up.
# You must place a valid cacert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY /cosmos-ruby/cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem

RUN apk add --update docker-compose

WORKDIR /cosmos/

COPY ./ ./

# RUN docker-compose -f /cosmos/docker-compose.yaml -f /cosmos/compose-build.yaml build
# RUN docker-compose -f /cosmos/docker-compose.yaml -f /cosmos/compose-dev.yaml build