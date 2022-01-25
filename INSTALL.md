# Install

This document describes how to install Cosmos using the cosmos-control and scripts directory.

- [Requirements](#Requirements)
- [Setup](#Setup)
- [Start](#Start)
- [Stop](#Stop)
- [Cleanup](#Cleanup)
- [Build](#Build)
- [Deploy](#Deploy)

## Optional Arguments

The most commands can also take arguments. The current argument options when running are listed.

- **dev**: Will download, build and run fluentd, opendistro elastic, opendistro kibana, prometheus, grafana. The memory footprint of these containers can cause some computers to not run Cosmos.

## Requirements

### Docker

- [Docker Install](https://docs.docker.com/engine/install/)

## Setup

To build you can use an environment variable `SSL_CERT_FILE` or it will default to use a public curl ca file. When you run setup it copys the `SSL_CERT_FILE` and will place a copy in the root of the cosmos repo as `cacert.pem`, along with the cosmos directory and the frontend directory. These are needed to build the docker containers.

If you're building in an air-gap environment or want to use a private Rubygems, NPM or APK server (e.g. Nexus) you can set the following environment variables: RUBYGEMS_URL, NPM_URL, APK_URL. The cosmos_setup.sh/bat files set the following defaults:

* RUBYGEMS_URL=https://rubygems.org
* NPM_URL=https://registry.npmjs.org
* APK_URL=http://dl-cdn.alpinelinux.org

### Windows

```
>cosmos-control.bat setup
```

### Linux

```
$ cosmos-control.sh setup
```

## Start

This will run the setup to make sure it has been run. It will build and run the minimal requirements for cosmos. This will create a docker network and volumes if they do not already exist. Then run the containers.
### Windows

```
>cosmos-control.bat start
```

### Linux

```
$ cosmos-control.sh start
```

## Stop

This will safely stop all cosmos containers and disconnect from all targets. This will **NOT** remove the docker network or volumes and thus all stored commands and telemetry are saved.

### Windows

```
>cosmos-control.bat stop
```

### Linux

```
$ cosmos-control.sh stop
```

## Cleanup

Note this is destructive and if successful **ALL** stored commands and telemetry are **deleted**. This will remove all docker volumes which will delete ALL stored commands and telemetry! This will **NOT** stop running docker containers.

### Windows

```
>cosmos-control.bat cleanup
```

### Linux

```
$ cosmos-control.sh cleanup
```

## Build

This will build all new containers. If cosmos is being used you will have to stop and start the containers to get the new build.

### Windows

```
>cosmos-control.bat build
```

### Linux

```
$ cosmos-control.sh build
```

## Deploy

Deploy built docker containers into a local docker repository.

### Windows

```
>cosmos-control.bat deploy
```

### Linux

```
$ cosmos-control.sh deploy
```