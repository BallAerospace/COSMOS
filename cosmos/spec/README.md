# COSMOS TESTS

## Environment

```
set COSMOS_DEVEL=\path\to\cosmos\cosmos
set RUBYGEMS_URL=https://rubygems.org
```

## Build

```
bundle install

rake build
```

## Run the test

From within the cosmos directory in the cosmos repo... aka `cosmos/cosmos` run `bundle exec rspec --color` or `bundle exec rake build spec`
