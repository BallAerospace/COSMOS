FROM fluent/fluentd:v1.10.3-1.0
COPY ./conf/fluent.conf /fluentd/etc/fluent.conf
USER root
RUN ["gem", "install", "fluent-plugin-elasticsearch", "--no-document", "--version", "4.0.7"]
USER fluent