FROM cosmos-base

# Set RUBYLIB so ruby can find COSMOS
ENV RUBYLIB=/cosmos/lib
WORKDIR /cosmos/lib/cosmos/operators
ENTRYPOINT [ "ruby" ]
CMD [ "microservice_operator.rb"]
