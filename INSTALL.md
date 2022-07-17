# Install

This document describes how to install OpenC3 using the openc3 shell scripts

- [Requirements](#Requirements)
- [Setup](#Setup)
- [Start](#Start)
- [Stop](#Stop)
- [Cleanup](#Cleanup)
- [Build](#Build)
- [Deploy](#Deploy)

## Optional Arguments

The most commands can also take arguments. The current argument options when running are listed.

## Requirements

### Docker

- [Docker Install](https://docs.docker.com/engine/install/)

## Setup

To build you can use an environment variable `SSL_CERT_FILE` or it will default to use a public curl ca file. When you run setup it copys the `SSL_CERT_FILE` and will place a copy in the root of the openc3 repo as `cacert.pem`. These are needed to build the docker containers.

If you're building and want to use a private Rubygems, NPM or APK server (e.g. Nexus) you can update the following environment variables: RUBYGEMS_URL, NPM_URL, APK_URL, and more in the .env file. Example values:

* ALPINE_VERSION=3.15
* ALPINE_BUILD=4
* RUBYGEMS_URL=https://rubygems.org
* NPM_URL=https://registry.npmjs.org
* APK_URL=http://dl-cdn.alpinelinux.org

### Windows

```
>openc3.bat setup
```

### Linux

```
$ openc3.sh setup
```

## Start

This will run the setup to make sure it has been run. It will build and run the minimal requirements for openc3. This will create a docker network and volumes if they do not already exist. Then run the containers.

### Windows

```
>openc3.bat start
```

### Linux

```
$ openc3.sh start
```

## Stop

This will safely stop all openc3 containers and disconnect from all targets. This will **NOT** remove the docker network or volumes and thus all stored commands and telemetry are saved.

### Windows

```
>openc3.bat stop
```

### Linux

```
$ openc3.sh stop
```

## Cleanup

Note this is destructive and if successful **ALL** stored commands and telemetry are **deleted**. This will remove all docker volumes which will delete ALL stored commands and telemetry! This will **NOT** stop running docker containers.

### Windows

```
>openc3.bat cleanup
```

### Linux

```
$ openc3.sh cleanup
```

## Build

This will build all new containers. If openc3 is being used you will have to stop and start the containers to get the new build.

### Windows

```
>openc3.bat build
```

### Linux

```
$ openc3.sh build
```

## Deploy

Deploy built docker containers into a local docker repository.

### Windows

```
>openc3.bat deploy
```

### Linux

```
$ openc3.sh deploy
```