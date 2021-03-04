FROM cosmos-base

COPY plugins /cosmos/plugins/
WORKDIR /cosmos/plugins/cosmos-demo/
COPY init.sh .

RUN ["rake", "build", "VERSION=5.0.0", "--quiet"]
CMD [ "/cosmos/plugins/cosmos-demo/init.sh" ]
