---
layout: news_item
title: 'Ball Aerospace COSMOS 5.0.0 alpha 1 Released'
date: 2020-08-31 6:00:00 -0700
author: ryanmelt
version: 5.0.0-alpha.1
categories: [release]
---

I am proud to announce the release of COSMOS 5 Alpha 1!  

COSMOS 5 is a highly scalable, cloud native, command and control software system.  This is a technology preview release meant to introduce all of the new technologies debuting in COSMOS 5. 

New Technologies:

* Docker - COSMOS 5 runs across a set of containers managed by Docker
* Redis - Redis is used as a key-value store, and streaming data server
* Minio - Minio provides an S3 compatible file storage server
* EFK Stack - Elasticsearch, Fluentd, Kibana - Provide a distributed logging solution
* Vue.js - Javascript technology used to build the new COSMOS user interface

Basic versions of the following COSMOS tools are included in this release:

* Command and Telemetry Server
* Command Sender
* Packet Viewer
* Telemetry Viewer
* Telemetry Grapher
* Script Runner
* Limits Monitor

### Prerequisites:

* Docker - Running COSMOS 5 requires a working Docker installation.  Typically Docker Desktop on Windows / Mac.  Plain docker should work on linux.  We're currently only developing / running with Docker Desktop on Windows, so if you have any issues on another platform, please let us know by submitting a ticket!

### To Run:

1. Download one of the archives (.zip or .tar.gz from the Github release page) [Download Release Here](https://github.com/BallAerospace/COSMOS/releases/tag/v5.0.0-alpha.1)
2. Extract the archive somewhere on your host computer
3. The COSMOS 5 containers are designed to work and be built in the presence of an SSL Decryption device.  To support this a cacert.pem file can be placed at the base of the COSMOS 5 project that includes any certificates needed by your organization.  If you don't need this, then please ignore, but if you see any SSL errors, this is probably why.
4. Run cosmos_start.bat (Windows), or cosmos_start.sh (linux/Mac)
5. COSMOS 5 will be built and when ready should be running (~15 mins for first run, ~2 for subsequent)
6. Connect a web browser to http://localhost:8080
7. Have fun trying out COSMOS 5!

Please try it out and let us know what you think!  Please submit any issues as Github tickets, or any generic feedback to COSMOS@ball.com.  

Note that this release is not ready for production use.  We will have a more beta ready release in a few months.

Thanks!
