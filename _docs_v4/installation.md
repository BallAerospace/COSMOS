---
layout: docs_v4
title: Installation
---

## Installing COSMOS

The following sections describe howto get COSMOS installed on various operating systems.

## Installing COSMOS using Docker

COSMOS is now available as Docker images. See our Docker documentation here:
[COSMOS Docker Directions](https://github.com/BallAerospace/cosmos-docker)

## Installing COSMOS on Host Machines

## Windows 7+

Run the COSMOS Installation bat file:

1. Right click this link and choose "Save Target As" or "Save Link As": [INSTALL_COSMOS.bat](https://raw.githubusercontent.com/BallAerospace/COSMOS/master/vendor/installers/windows/INSTALL_COSMOS.bat)
2. Save the file to your harddrive
3. Run the bat from from Windows explorer or a cmd window

<div class="note warning">
  <h5>NEW - Windows 7: Powershell 4.0 Required</h5>
  <p style="margin-bottom:20px;">Most websites now require TLS 1.2 for downloads.  The version of powershell included by default with Windows 7 does not have support for TLS 1.2 which causes downloads to fail.  Before running the COSMOS installer bat file, you must install Powershell 4 which is part of Windows Management Framework 4 which can be found here:  <a href="https://www.microsoft.com/en-us/download/details.aspx?id=40855">Windows Management Framework 4</a></p>
  <p><img src="/img/windows7error.png" alt="Windows7Error"></p>
</div>

<div class="note warning">
  <h5>SSL Issues</h5>
  <p style="margin-bottom:20px;">The COSMOS install scripts use command line tools like curl to download the code necessary for COSMOS across https connections.  Increasingly organizations are using some sort of SSL decryptor device which can cause curl and other command line tools like git to have SSL certificate problems.  If installation fails with messages that involve "certificate", "SSL", "self-signed", or "secure" this is the problem.  IT typically sets up browsers to work correctly but not command line applications. Note that the file extension might not be .pem, it could be .pem, crt, .ca-bundle, .cer, .p7b, .p7s, or  potentially something else.</p>
  <p style="margin-bottom:20px;">The workaround is to get a proper local certificate file from your IT department that can be used by tools like curl (for example mine is at C:\Shared\Ball.pem).   Doesn't matter just somewhere with no spaces.</p>
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

<div class="note info">
  <h5>Offline Installation</h5>
  <p>The COSMOS installation batch file downloads all the components of the COSMOS system from the Internet. If you want to create an offline installer simply zip up the resulting installation directory. Then manually create the COSMOS_DIR environment variable to point to the root directory where you unzip all the installation files. You might also want to add \<COSMOS\>\Vendor\Ruby\bin to your path to allow access to Ruby from your terminal.</p>
</div>

<div class="note warning">
  <h5>Note on Internet Explorer</h5>
  <p>If you left click the link above and try to save it, IE will corrupt the bat file. Don't download using Internet Explorer.</p>
</div>

## CentOS Linux 6.5/6.6/7, Ubuntu Linux 14.04LTS, and Mac OSX Mavericks+

The following instructions work for an installation on CentOS Linux 6.5,s 6.6, or 7, and Ubuntu 14.04LTS from a clean install or any version of Mac OS X after and include Mavericks. Similar steps should work on other distributions/versions, particularly Redhat.

Run the following command in a terminal running the **bash** shell:

```
bash <(\curl -sSL https://raw.githubusercontent.com/BallAerospace/COSMOS/master/vendor/installers/linux_mac/INSTALL_COSMOS.sh)
```

<div class="note warning">
  <h5>Issues with http_proxy</h5>
  <p style="margin-bottom:20px;">If you are using the http_proxy environment variable to use a proxy server, you MUST also have a no_proxy variable that includes 127.0.0.1 for COSMOS to work.  Note that 127.0.0.0/8 in a no_proxy variable does not work with COSMOS.  It must contain exactly 127.0.0.1</p>
</div>

## Linux Notes

The install script will install all needed dependencies using the system package manager and install ruby using rbenv. If another path to installing COSMOS is desired please feel free to just use the INSTALL_COSMOS.sh file as a basis. As always, it is a good idea to review any remote shell script before executing it on your system.

If installing in an environment where SSL Certificates are not setup correctly. The following commands will let COSMOS install in an insecure fashion:

```
echo "insecure" >> ~/.curlrc
export RUBY_BUILD_CURL_OPTS="-k"
git config --global http.sslVerify false
bash <(\curl -sSL https://raw.githubusercontent.com/BallAerospace/COSMOS/master/vendor/installers/linux_mac/INSTALL_COSMOS.sh)
```

## Mac Notes

The install script will install all needed dependencies using homebrew and install ruby using rbenv. If another path to installing COSMOS is desired please feel free to just use the INSTALL_COSMOS.sh file as a basis. As always, it is a good idea to review any remote shell script before executing it on your system.

In the tools/mac folder is a Mac application version of each tool. Launcher.app can be copied into the overall Mac applications folder or the Desktop for easy launching. For this to work you need to set an environment variable for each user so that COSMOS can find it configuration files:

In your .bash_profile add this line (point to your actual COSMOS configuration folder):

```
export COSMOS_USERPATH=/Users/username/demo
```

Alternative Install directions using Mac Ports:

```
sudo port install qt4-mac
sudo port install ruby24
sudo port select --set ruby ruby24
sudo gem install ruby-termios
sudo gem install cosmos
```

You should have a working install and can now create
a sample COSMOS directory structure where you can
configure and run cosmos. To create a test area do
this:

```
cosmos demo test
cd test
ruby Launcher
```

## General

Notes:

1. The bash shell is required on Linux and Mac

1. ruby-termios is a dependency of COSMOS on non-windows platforms but is not listed in the gem dependencies because it is not a dependency on Windows. An extension attempts to install it when gem install cosmos is run. This should work as long as you are online. If attempting an offline installation of cosmos you will need to first manually install ruby-termios: `gem install ruby-termios`

1. The http_proxy environment variable can cause problems. Make sure you also have a no_proxy variable for localhost, something like no_proxy="127.0.0.1, localhost".
