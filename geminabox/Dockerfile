FROM cosmos-base

WORKDIR /src/

# Copy the local package files to the container's workspace
COPY . /src/

RUN ["bundle", "install", "--quiet"]

EXPOSE 9292

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0"]
