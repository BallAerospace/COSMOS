FROM cosmos-base

ENV RUBYLIB /cosmos/lib
ENV COSMOS_ENTERPRISE_PATH="/src/cosmos-enterprise"

COPY plugins /cosmos/plugins

WORKDIR /cosmos/plugins/cosmos-demo

COPY init.sh .

RUN ["bundle", "install", "--quiet"]

RUN ["rake", "build", "VERSION=5.0.0", "--quiet"]

CMD [ "/cosmos/plugins/cosmos-demo/init.sh" ]
