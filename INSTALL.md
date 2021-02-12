# Install

This document describes how to install Cosmos.

- [Requirements](#Requirements)
- [Setup](#Setup)
- [Start](#Start)
- [Stop](#Stop)
- [Cleanup](#Cleanup)
- [Build](#Build)
- [Deploy](#Deploy)
- [Start Dev](#Start_Dev)

## Requirements

### Docker

- [Docker Install](https://docs.docker.com/engine/install/)

## Setup

To build you can use an environment variable `SSL_CERT_FILE` or it will default to use a public curl ca file. When you run setup it copys the `SSL_CERT_FILE` and will place a copy in the root of the cosmos repo as `cacert.pem`, along with the cosmos directory and the frontend directory. These are needed to build the docker containers.

### Windows

```
C:\COSMOS>cosmos_control.bat setup
```

### Linux

```
$ pwd
/COSMOS/
$ cosmos_control.sh setup
```

## Start

This will run the setup to make sure it has been run. It will build and run the minimal requirements for cosmos. This will create a docker network and volumes if they do not already exist. Then run the containers.

### Windows

```
C:\COSMOS>cosmos_control.bat start
```

### Linux

```
$ pwd
/COSMOS/
$ cosmos_control.sh start
```

## Stop

This will safely stop all cosmos containers and disconnect from all targets. This will **NOT** remove the docker network or volumes and thus all stored commands and telemetry are saved.

### Windows

```
C:\COSMOS>cosmos_control.bat stop
```

### Linux

```
$ pwd
/COSMOS/
$ cosmos_control.sh stop
```

## Cleanup

Note this is destructive and if successful **ALL** stored commands and telemetry are **deleted**. This will remove all docker volumes which will delete ALL stored commands and telemetry! This will **NOT** stop running docker containers.

### Windows

```
C:\COSMOS>cosmos_control.bat cleanup
```

### Linux

```
$ pwd
/COSMOS/
$ cosmos_control.sh cleanup
```

## Build

This will build all new containers. If cosmos is being used you will have to stop and start the containers to get the new build.

### Windows

```
C:\COSMOS>cosmos_control.bat build
```

### Linux

```
$ pwd
/COSMOS/
$ cosmos_control.sh build
```

## Deploy

Use if you have a local docker repository that you can publish docker containers to for being pulled via addtional users.

### Windows

```
C:\COSMOS>cosmos_control.bat deploy
```

### Linux

```
$ pwd
/COSMOS/
$ cosmos_control.sh deploy
```

## Start_Dev

This will run setup and start Cosmos but also build and run fluentd, opendistro elastic, opendistro kibana, prometheus, grafana. The memory footprint of these containers can cause some computers to not run Cosmos.

### Windows

```
> C:\COSMOS>cosmos_control.bat start_dev
```

### Linux

```
$ pwd
/COSMOS/
$ cosmos_control.sh start_dev
```