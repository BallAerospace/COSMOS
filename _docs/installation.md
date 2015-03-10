---
layout: docs
title: Installation
permalink: /docs/installation/
---

##General

Notes:

1. ruby-termios is a dependency of COSMOS on non-windows platforms but is not listed in the gem dependencies because it is not a dependency on Windows.  An extension attempts to install it when gem install cosmos is run.  This should work as long as you are online. If attempting an offline installation of cosmos you will need to first manually install ruby-termios: gem install ruby-termios.

1. No testing has been done yet with Ruby 2.2, but it should work easily on all platforms but windows.  Ruby 2.1 is recommended for now.

1. Installing the COSMOS gem (and many other binary gems) with rdoc 4.0.0 spits outs warnings like this:
{% highlight bash %}
unable to convert "\x90" from ASCII-8BIT to UTF-8 for lib/cosmos/ext/array.so, skipping
{% endhighlight %}

These are just warnings and can be safely ignored.  Updating rdoc before installing cosmos will remove the warnings: gem install rdoc.

##Windows (ONLY 32-bit Ruby Supported)
1. Install the 32-bit version of Ruby 2+ using the installer from http://rubyinstaller.org
1. Install the 32-bit version of Devkit for Ruby 2+ using the self extracting archive from http://rubyinstaller.org (Recommended install path is C:\Devkit)
1. Open a cmd shell
1. Add Devkit to your path by running C:\Devkit\devkitvars.bat
1. Install the cosmos gem
    * {% highlight bash %}
    gem install cosmos
    {% endhighlight %}
1. Create a cosmos demo project somewhere using:
    * {% highlight bash %}
    cosmos demo demo
    {% endhighlight %}
1. Run the COSMOS Launcher using Launcher.bat or running: ruby Launcher

<div style="max-width:800px;margin:0px auto;padding:20px;">
  <section class="video-container" style="margin-bottom:20px;">
    <center><iframe width="560" height="315" src="https://www.youtube.com/embed/Mk5Uxe7v6xA" frameborder="0" allowfullscreen></iframe></center>
  </section>
</div>

Note: There is a binary Windows installer available for U.S. customers with a support contract.

##CentOS Linux 6.5
The following instructions work for an installation on CentOS Linux 6.5 from a clean install with "Software Development Workstation" selected as the installation type.  Similar steps should work on other distributions/versions.

1. Update all system packages
    * {% highlight bash %}
    su -c 'yum update'
    {% endhighlight %}
1. Install rvm
    1. \curl -sSL https://get.rvm.io &#124; bash -s stable
    1. Move the \[\[ -s "$HOME/.rvm/scripts/rvm" \]\] && source "$HOME/.rvm/scripts/rvm" line from the bottom of .bash_profile to the bottom of .bashrc
1. Install qt4 (This may already be installed depending on your version of Centos.  COSMOS does work fine with the version of Qt available in yum Qt4.6.2.  If you want to install the latest supported version by COSMOS follow the directions below:)
    1.  yum install gstreamer-plugins-base-devel
    1. wget http://download.qt-project.org/official_releases/qt/4.8/4.8.6/qt-everywhere-opensource-src-4.8.6.tar.gz
    1. tar xvzf qt-everywhere-opensource-src-4.8.6.tar.gz
    1. cd qt-everywhere-opensource-src-4.8.6
    1. ./configure
    1. o (for open-source)
    1. gmake
    1. sudo gmake install
    1. add the followings to .bashrc:
        * export PATH="$PATH:/usr/local/Trolltech/Qt-4.8.6/bin"
1. Restart your terminal
1. Install Ruby 2.1.5 for the current user (A system wide installation might be more appropriate for your use case)
    * {% highlight bash %}
    rvm install 2.1.5 -C --enable-shared
    rvm use 2.1.5 --default
    {% endhighlight %}
1. Install cmake
    1. sudo yum install cmake
1. Install glut
    1. sudo yum install freeglut freeglut-devel
1. Install the cosmos gem
    1. gem install cosmos
1. Create a demo working area
    1. cosmos demo demo
    1. cd demo
    1. ruby Launcher

##MacOS 10.9 (Mavericks) or 10.10 (Yosemite)
1. Disable App Nap Globally
    1. defaults write -g NSAppSleepDisabled -bool true
1. Install Xcode
    1. App Store - Search Xcode - Install
1. Update Xcode and the OS
    1. App Store - Updates - Install all OS and Xcode updates
1. Install Homebrew
    * {% highlight bash %}
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    {% endhighlight %}
1. Install libksba
    1. brew install libksba
1. Install cmake
    1. brew install cmake
1. Install QT (this currently installs version 4.8.6 on Mavericks).  Installing with the gist below adds an additional patch that removes modalSession warnings (recommended).  Note that this will probably take over an hour to build and install.  This resolves this issue for 4.8.6: https://bugreports.qt.io/browse/QTBUG-37699.
    1. brew uninstall qt
    1.  Run the following brew command:
      * {% highlight bash %}
      brew install https://gist.githubusercontent.com/ryanmelt/8280d83562616f8f3adc/raw/099e4bde94faad9596b2f2100fe49f25e82931fb/qt.rb --build-from-source
      {% endhighlight %}
1. Install rvm
    1. \curl -sSL https://get.rvm.io &#124; bash -s stable
1. Install Ruby 2.1.5 for the current user (A system wide installation might be more appropriate for your use case)
    * {% highlight bash %}
    rvm install 2.1.5 -C --enable-shared --with-gcc=clang
    rvm use 2.1.5 --default
    {% endhighlight %}
1. Install the cosmos gem
    1. gem install cosmos
1. Create a demo working area
    1. cosmos demo demo
    1. cd demo
    1. ruby Launcher
1. In the tools/mac folder is a Mac application version of each tool.    Launcher.app can be copied into the overall Mac applications folder or the Desktop for easy launching.   For this to work you need to set an environment variable for each user so that COSMOS can find it configuration files:
    1. in .bash_profile add this line:
        1. export COSMOS_USERPATH=/Users/username/demo
