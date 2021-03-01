FROM cosmos-base

ENV RUBYLIB /cosmos/lib

COPY plugins /cosmos/plugins

WORKDIR /cosmos/plugins/cosmos-demo

COPY init.sh .

RUN ["bundle", "install", "--quiet"]

CMD [ "/cosmos/plugins/cosmos-demo/init.sh" ]
