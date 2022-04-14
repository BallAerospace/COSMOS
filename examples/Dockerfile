FROM ballaerospace/cosmosc2-base

USER ${USER_ID}:${GROUP_ID}

WORKDIR /cosmos/examples/

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} external_script.rb .

ENV COSMOS_API_HOSTNAME host.docker.internal

CMD ["ruby", "/cosmos/examples/external_script.rb"]