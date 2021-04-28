---
layout: news_item
title: "Ball Aerospace COSMOS 5.0.0 beta 2 Released"
date: 2021-04-12 6:00:00 -0700
author: ryanmelt
version: 5.0.0.beta2
categories: [release]
---

I am proud to announce the release of COSMOS 5 Beta 2!

COSMOS 5 is a highly scalable, cloud native, command and control software system. This second beta release is intended for users to begin to experiment with and prepare for the production COSMOS 5 release scheduled for June.

Changes from the Beta 1 Release:

- COSMOS tools are now modular and can be added with plugins
- Improved Stability and Testing
- Improved API support from COSMOS 4
- Improved Project Organization and Naming Consistency
- New DataViewer Tool
- New Notifications System
- Streaming API now supports streaming raw packet data
- Improved Admin Functionality
- Improved TlmViewer Widget support
- Classification Banner Support
- Support for Raw Logging
- Open source license changed from GPLv3 to AGPLv3
- Removed EFK stack from running by default

COSMOS 5 Technologies:

- Docker - COSMOS 5 runs across a set of containers managed by Docker
- Redis - Redis is used as a key-value store, and streaming data server
- Minio - Minio provides an S3 compatible file storage server
- Vue.js - Javascript technology used to build the new COSMOS user interface

Functional versions of the following COSMOS tools are included in this release:

- Command and Telemetry Server
- Command Sender
- Packet Viewer
- Telemetry Viewer
- Telemetry Grapher
- Script Runner (Test Runner now built in)
- Limits Monitor
- Extractor
- Data Viewer
- Admin Interface

Known Things That Aren't Done/Fully Working Yet:

- Data Reduction
- The LATEST telemetry packet
- Serial Interface Support (probably would work on a linux host with the cosmos-operator container running with --privileged)
- New Timeline Feature

### Prerequisites:

Docker - Running COSMOS 5 requires a working Docker installation. Typically Docker Desktop on Windows / Mac. Plain docker should work on linux. We're currently only developing / running with Docker Desktop on Windows, so if you have any issues on another platform, please let us know by submitting a ticket!

Minimum Resources allocated to Docker: 8GB RAM, 1 CPU, 80GB Disk
Recommended Resources allocated to Docker: 16GB RAM, 2+ CPUs, 100GB Disk

### To Run:

1. Download one of the archives (.zip or .tar.gz from the Github release page) [Download Release Here](https://github.com/BallAerospace/COSMOS/releases/tag/v5.0.0-beta.2)
2. Extract the archive somewhere on your host computer
3. The COSMOS 5 containers are designed to work and be built in the presence of an SSL Decryption device. To support this a cacert.pem file can be placed at the base of the COSMOS 5 project that includes any certificates needed by your organization. If you don't need this, then please ignore, but if you see any SSL errors, this is probably why.
4. Run cosmos-control.bat start (Windows), or ./cosmos-control.sh start (linux/Mac)
5. COSMOS 5 will be built and when ready should be running (~20 mins for first run, ~3 for subsequent)
6. Connect a web browser to http://localhost:2900
7. Have fun trying out COSMOS 5!

We will be actively updating documentation on cosmosc2.com throughout the month of April. So if it isn't documented yet, we're getting there! The biggest new documentation is on the new plugin system.

Please try it out and let us know what you think! Please submit any issues as Github tickets, or any generic feedback to COSMOS@ball.com.

Note that this release is not recommended for production use, but at this point you are encouraged to start migrating and working through any initial issues.

Thanks!
