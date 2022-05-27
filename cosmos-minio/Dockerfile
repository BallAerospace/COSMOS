ARG COSMOS_REGISTRY=docker.io

FROM ${COSMOS_REGISTRY}/minio/minio:RELEASE.2021-06-17T00-10-46Z

COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem
ENV NODE_EXTRA_CA_CERTS=/devel/cacert.pem
