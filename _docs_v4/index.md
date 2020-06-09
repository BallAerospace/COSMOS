---
layout: docs_v4
title: Welcome
---

This site aims to be a comprehensive guide to COSMOS. We'll cover topics such
as getting your configuration up and running, developing test and operations scripts,
building custom telemetry screens, and give you some advice on participating in the future
development of COSMOS itself.

[Click here for a PDF version of this webpage]({{ site.url }}/assets/COSMOS_Docs_10_24_2018.pdf)

## So what is Ball Aerospace COSMOS, exactly?

COSMOS is a suite of applications that can be used to control a set of embedded systems. These systems can be
anything from test equipment (power supplies, oscilloscopes, switched power strips, UPS devices, etc), to
development boards (Arduinos, Raspberry Pi, Beaglebone, etc), to satellites.

### COSMOS Architecture

![COSMOS Architecture](/img/tools/architecture.png)

COSMOS implements a client server architecture with the Command and Telemetry Server and the various other tools typically acting as clients to retreive data. The Command and Telemetry Server connects to the Targets (green circles) and sends commands and receives telemetry (status data) from them. Targets are the items you're trying to control or get status from. The arrows from the Server to the targets indicate Interfaces which can be over TCP/IP, serial, UDP/IP, or a custom interface that you define. Yellow boxes indicate data items like configuration files, log files, reports, etc.

Keep reading for an in-depth discussion of each of the COSMOS Tools.

## Helpful Hints

Throughout this guide there are a number of small-but-handy pieces of
information that can make using COSMOS easier, more interesting, and less
hazardous. Here's what to look out for.

<div class="note">
  <h5>ProTips™ help you get more from COSMOS</h5>
  <p>These are tips and tricks that will help you be a COSMOS wizard!</p>
</div>

<div class="note info">
  <h5>Notes are handy pieces of information</h5>
  <p>These are for the extra tidbits sometimes necessary to understand
     COSMOS.</p>
</div>

<div class="note warning">
  <h5>Warnings help you not blow things up</h5>
  <p>Be aware of these messages if you wish to avoid certain death.</p>
</div>

<div class="note unreleased">
  <h5>You'll see this by a feature that hasn't been released</h5>
  <p>Some pieces of this website are for future versions of COSMOS that
    are not yet released.</p>
</div>

If you come across anything along the way that we haven't covered, or if you
know of a tip you think others would find handy, please [file an
issue]({{ site.repository }}/issues/new) and we'll see about
including it in this guide.
