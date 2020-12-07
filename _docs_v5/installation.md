---
layout: docs
title: Installation
---

## Installing COSMOS

The following sections describe how to get COSMOS installed on various operating systems.

## Installing COSMOS on Host Machines

1. Install [Docker](https://docs.docker.com/get-docker/)
1. Download the latest COSMOS 5 from the Github [releases](https://github.com/BallAerospace/COSMOS/releases)
1. Extract the archive somewhere on your host computer
1. The COSMOS 5 containers are designed to work and be built in the presence of an SSL Decryption device. To support this a cacert.pem file can be placed at the base of the COSMOS 5 project that includes any certificates needed by your organization.
1. Run cosmos_start.bat (Windows), or cosmos_start.sh (linux/Mac)
1. COSMOS 5 will be built and when ready should be running (~15 mins for first run, ~2 for subsequent)
1. Connect a web browser to http://localhost:8080

<div class="note warning">
  <h5>SSL Issues</h5>
  <p style="margin-bottom:20px;">Increasingly organizations are using some sort of SSL decryptor device which can cause curl and other command line tools like git to have SSL certificate problems. If installation fails with messages that involve "certificate", "SSL", "self-signed", or "secure" this is the problem. IT typically sets up browsers to work correctly but not command line applications. Note that the file extension might not be .pem, it could be .pem, crt, .ca-bundle, .cer, .p7b, .p7s, or  potentially something else.</p>
  <p style="margin-bottom:20px;">The workaround is to get a proper local certificate file from your IT department that can be used by tools like curl (for example mine is at C:\Shared\Ball.pem). Doesn't matter just somewhere with no spaces.</p>
  <p style="margin-bottom:20px;">Then set the following environment variables to that path (ie. C:\Shared\Ball.pem)</p>

<p style="margin-left:20px;margin-bottom:20px;">
SSL_CERT_FILE<br/>
CURL_CA_BUNDLE<br/>
REQUESTS_CA_BUNDLE<br/>
</p>

<p style="margin-bottom:20px;">
Here are some directions on environment variables in Windows:
<a href="https://www.computerhope.com/issues/ch000549.htm">Windows Environment Variables</a><br/>
You will need to create new ones with the names above and set their value to the full path to the certificate file.
</p>
<p style="margin-bottom:20px;">After these changes the installer should work. At Ball please contact <a href="mailto:COSMOS@ball.com">COSMOS@ball.com</a> for assistance.</p>
</div>
