FROM cosmos-base

WORKDIR /src/
COPY . .
RUN ["bundle", "install", "--quiet", "--without=development"]

EXPOSE 2902
CMD ["rails", "s", "-b", "0.0.0.0", "-p", "2902"]
