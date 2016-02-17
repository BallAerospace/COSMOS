---
layout: docs
title: Installation
permalink: /docs/installation/
---

##Windows 7+
Run the COSMOS Installation bat file:

  1. Goto this link: [INSTALL_COSMOS.bat](https://raw.githubusercontent.com/BallAerospace/COSMOS/master/vendor/installers/windows/INSTALL_COSMOS.bat)
  2. Choose Save As... in your browser to save the file to your harddrive
  3. Run the bat from from Windows explorer or a cmd window

NOTE: The COSMOS installation batch file downloads all the components of the COSMOS system from the Internet. If you want to create an offline installer simply zip up the resulting installation directory. Then manually create the COSMOS_DIR environment variable to point to the root directory where you unzip all the installation files. You might also want to add \<COSMOS\>\Vendor\Ruby\bin to your path to allow access to Ruby from your terminal.

##CentOS Linux 6.5/6.6/7, Ubuntu Linux 14.04LTS, and Mac OSX Mavericks+
The following instructions work for an installation on CentOS Linux 6.5, 6.6, or 7, and Ubuntu 14.04LTS from a clean install or any version of Mac OSX after and include Mavericks.  Similar steps should work on other distributions/versions, particularly Redhat.

Run the following command in a terminal:

```
bash <(\curl -sSL https://raw.githubusercontent.com/BallAerospace/COSMOS/master/vendor/installers/linux_mac/INSTALL_COSMOS.sh)
```

##Linux Notes

The install script will install all needed dependencies using the system package manager and install ruby using rbenv.   If another path to installing COSMOS is desired please feel free to just use the INSTALL_COSMOS.sh file as a basis.  As always, it is a good idea to review any remote shell script before executing it on your system.

##Mac Notes

The install script will install all needed dependencies using homebrew and install ruby using rbenv.   If another path to installing COSMOS is desired please feel free to just use the INSTALL_COSMOS.sh file as a basis.  As always, it is a good idea to review any remote shell script before executing it on your system.

In the tools/mac folder is a Mac application version of each tool.    Launcher.app can be copied into the overall Mac applications folder or the Desktop for easy launching.   For this to work you need to set an environment variable for each user so that COSMOS can find it configuration files:

In your .bash_profile add this line (point to your actual COSMOS configuration folder):

```
export COSMOS_USERPATH=/Users/username/demo
```

##General

Notes:

1. ruby-termios is a dependency of COSMOS on non-windows platforms but is not listed in the gem dependencies because it is not a dependency on Windows.  An extension attempts to install it when gem install cosmos is run.  This should work as long as you are online. If attempting an offline installation of cosmos you will need to first manually install ruby-termios: ```gem install ruby-termios```

1. Installing the COSMOS gem (and many other binary gems) with rdoc 4.0.0 spits outs warnings like this:
{% highlight bash %}
unable to convert "\x90" from ASCII-8BIT to UTF-8 for lib/cosmos/ext/array.so, skipping
{% endhighlight %}

These are just warnings and can be safely ignored.  Updating rdoc before installing cosmos will remove the warnings: gem install rdoc.
