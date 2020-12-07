---
layout: docs
title: Securing COSMOS
toc: true
---

This document describes how to secure a COSMOS installation.

## Overview

COSMOS is primarily secured by properly configuring settings with the system.txt configuration file. The following settings are important.

| Setting                 | Description                                                                                                                                    | Recommended Settings                                                                                                                                                        |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X_CSRF_TOKEN            | This is a secret value included in all API requests.                                                                                           | Change this from the default to something different for each project.                                                                                                       |
| LISTEN_HOST             | These settings define if TCP/IP servers opened by COSMOS accept connections from just localhost (127.0.0.1), or external connections (0.0.0.0) | It is recommended to leave these all set at 127.0.0.1 unless you need to allow external access                                                                              |
| ALLOW_HOST              | Adds to the list of allowed hosts in the HTTP Host header of COSMOS API requests. Defaults to just localhost:7777, localhost:7778, etc.        | To allow connections to COSMOS APIs from external computers you will need to add YourCOSMOSServerIP:7777, YourCOSMOSServerIP:7778, etc.                                     |
| ALLOW_ORIGIN            | Used to specify websites that are allowed to access COSMOS. Default to None.                                                                   | Add the hostname and port of websites that should be allowed to access the COSMOS API. Typically None                                                                       |
| ALLOW_ACCESS            | Specifies hosts (IP Addresses) that are allowed to connect                                                                                     | This setting still defaults to ALL, but for enhanced security, only allow connections from expected external computers.                                                     |
| ALLOW_ROUTER_COMMANDING | Allows COSMOS routers to accept commands and forward them to interfaces.                                                                       | It is recommended that you do NOT include this line in your system.txt file unless you need to send commands through routers (such as some CmdTlmServer chaining use cases) |

## Summary

Setting the above settings correctly will provide a relatively secure COSMOS installation.
For enhanced security, please ask about our upcoming COSMOS Enterprise Edition product.
