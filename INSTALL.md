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

This will run the setup to make sure it has been run. It will then run the minimal requirements to start cosmos. This will create a docker network and volumes if they do not already exist, along with building the containers. Then run the containers.

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

This will stop all cosmos containers. This will **NOT** remove the docker network or volumes.

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

This will **try to remove** all volumes and network. If these are currently in use then it will give errors. This will **NOT** stop running docker containers.

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

Use if you have a local docker repository. That you can publish docker containers to.

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

Use if you want to have more tools about what cosmos is doing. This will also build and run fluentd, opendistro elastic, opendistro kibana, prometheus, grafana. The memory footprint of these containers can cause some computers to not run Cosmos.

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