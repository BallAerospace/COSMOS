# OPENC3 TESTS

## Environment

```
set OPENC3_DEVEL=\path\to\openc3\openc3
set RUBYGEMS_URL=https://rubygems.org
```

## Build

```
bundle install

rake build
```

## Run the test

From within the openc3 directory in the openc3 repo... aka `openc3/openc3` run `bundle exec rspec --color` or `bundle exec rake build spec`
