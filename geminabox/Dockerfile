FROM cosmos-base

WORKDIR /src/
COPY . .
RUN ["bundle", "install", "--quiet"]

EXPOSE 9292
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0"]
