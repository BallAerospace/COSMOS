---
layout: news_item
title: 'Ball Aerospace COSMOS 4.5.0 Released'
date: 2020-11-05 6:00:00 -0700
author: ryanmelt
version: 4.5.0
categories: [release]
---

COSMOS 4.5 - 

This is a security and bug fix release.  All users are recommended to update. Please see the migration notes below for necessary changes when upgrading from 4.4.2.

### Security Updates:

* [#672](https://github.com/BallAerospace/COSMOS/issues/672) Secure COSMOS API with Shared Secret
* [#1227](https://github.com/BallAerospace/COSMOS/issues/1227) Prevent a Malicious Website From Sending Commands

### Bug Fixes:

* [#1135](https://github.com/BallAerospace/COSMOS/issues/1135) Command Sequence Tool Overriding String Parameter
* [#1151](https://github.com/BallAerospace/COSMOS/issues/1151) CmdSender not setting description
* [#1158](https://github.com/BallAerospace/COSMOS/issues/1158) Loss of 1 us precision on CCSDS time when using Time.ccsds2sec method
* [#1164](https://github.com/BallAerospace/COSMOS/issues/1164) CmdTlmServer#reload always uses default system.txt
* [#1167](https://github.com/BallAerospace/COSMOS/issues/1167) Serial Driver Initialization Bug
* [#1196](https://github.com/BallAerospace/COSMOS/issues/1196) COSMOS windows stuck offscreen at Startup
* [#1200](https://github.com/BallAerospace/COSMOS/issues/1200) Handbook PDF Generation wkhtmltopdf ProtocolUnknownError
* [#1210](https://github.com/BallAerospace/COSMOS/issues/1210) Move CheckError definition to ApiShared

### New Features:

* [#1141](https://github.com/BallAerospace/COSMOS/issues/1141) Enable setting arbitrary bits in the serial drivers


### Maintenance:
* [#1136](https://github.com/BallAerospace/COSMOS/issues/1136) Telemetry Extractor delimiter on last item

### Migration Notes from COSMOS 4.4,x:
To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

Modify you system.txt files to:

1. Make sure you have a X_CSRF_TOKEN line with a unique value (anything will do, just change it)
2. Change all LISTEN_HOST settings to 127.0.01 unless you need connections from external hosts
3. If you know only specific external hosts will be connecting, add ALLOW_ACCESS lines for each
4. Only add ALLOW_ROUTER_COMMANDING if you are chaining CmdTlmServers (that need to send commands), or you are receiving commands through routers
5. Only add ALLOW_ORIGIN <Address of webpage>if you expect COSMOS to be accessed from a webpage
6. Add ALLOW_HOST <Your COSMOS IP Address>:7777, etc if you expect the COSMOS APIs to be accessed from external computers.  Otherwise it will only accept connections that have a HOST header set to localhost

