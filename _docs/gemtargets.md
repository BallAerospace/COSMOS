---
layout: docs
title: Gem Based Targets and Tools
permalink: /docs/gemtargets/
---

COSMOS supports sharing and reusing targets and tools by bundling the target and tool configuration and code into Ruby gems.
This document provides the information necessary to use and create gem based targets and tools.

## Using Gem Based Targets

Step one is to install the gem based target into you COSMOS project by adding a line like the following to your project Gemfile:

{% highlight ruby %}

# Gemfile
gem 'cosmos-xxxxxx' # Name of your gem here.  All should start with cosmos-

{% endhighlight %}

After making the Gemfile modification above, you can install the gem by running ```bundle install``` in your COSMOS project folder.  Note if the gem is not hosted at rubygems.org and you just have the file locally, you will most likely need to manually ```gem install cosmos-xxxxxxx.gem``` before running ```bundle install```.

Step two is to let the COSMOS system know about the gem based target in config/system/system.txt:

{% highlight bash %}

# system.txt

# Declare all installed gem based targets in your Gemfile
AUTO_DECLARE_TARGETS # This will discover any gem based targets automatically

# Individually specify targets (and possibly rename)
DECLARE_GEM_TARGET cosmos-xxxxxx

{% endhighlight %}

Step three is to configure the interface to the target in config/tools/cmd_tlm_server/cmd_tlm_server.txt.  This is done exactly the same way as any other target.

Step four is to configure telemetry screens in config/tools/tlm_viewer/tlm_viewer.txt.  This is again done exactly the same way as any other target.

That's it!  You should now be able to connect and interact with your gem based target.

## Using Gem Based Tools

First, install the gem based tool into your COSMOS project in the same way as installing a target gem above.  Then you will need to tell the COSMOS Launcher about the tool in launcher.txt like so:

{% highlight bash %}

# launcher.txt

# Provide buttons for all gem based tools
AUTO_GEM_TOOLS

# Or a just specific one
TOOL "XXXXXX" "LAUNCH_GEM Xxxxxx" "xxxxxxx.png"

{% endhighlight %}

That's it!  Click the new button in launcher to launch the tool.

## Creating Gem Based Targets

Creating gem based targets is easy. All that is required is creating a cosmos-xxxxxx.gemspec (replace xxxxxxx with your target name) file in the target folder you wish to make into a gem.
The folder structure should be just like what is in a normal target folder (ie.):

{% highlight bash %}

├── cosmos-xxxxxx.gemspec
├── cmd_tlm_server.txt
├── target.txt
├── cmd_tlm
|  └── # Target command and telemetry definition files here
├── lib
|  └── # Any necessary target code here
└── screens
|  └── # Target telemetry screen files

{% endhighlight %}

The gem name must start with "cosmos-", and should then be followed by the actual target name.  For example: cosmos-apcpdu.gemspec could be the gem name for a target called APCPDU.

Example config/targets/XXXXXX/cosmos-xxxxxx.gemspec file:

{% highlight ruby %}
# encoding: ascii-8bit

require 'rbconfig'

# Create the overall gemspec
spec = Gem::Specification.new do |s|
  s.name = 'cosmos-xxxxxx' # UPDATE WITH YOUR GEM NAME (must start with cosmos-)
  s.summary = 'Ball Aerospace COSMOS target' # UPDATE
  s.description =  <<-EOF
    Example gem based target # UPDATE
  EOF
  s.authors = ['Your Name'] # UPDATE
  s.email = ['yourname@yourcompany.com'] # UPDATE

  s.platform = Gem::Platform::RUBY
  if ENV['VERSION']
    s.version = ENV['VERSION'].dup
  else
    s.version = '0.0.0'
  end
  s.license = 'GPL-3.0' # UPDATE

  # Modify as needed
  s.files = Dir['lib/*'] + Dir['cmd_tlm/*'] + Dir['screens/*'] + ['cmd_tlm_server.txt', 'target.txt']

  s.has_rdoc = true

  s.required_ruby_version = '~> 2'

  # Runtime Dependencies
  s.add_runtime_dependency 'cosmos', '~> 3', '>= 3.7.0'
end

{% endhighlight %}

After organizing the files as required and creating the gemspec, create the actual gem with the following:

{% highlight bash %}
# Windows - update VERSION as needed
set VERSION=1.0.0
gem build cosmos-xxxxxx.gemspec

# Linux/Mac - update VERSION as needed
export VERSION=1.0.0
gem build cosmos-xxxxxx.gemspec
{% endhighlight %}

To publish your gem for other COSMOS users consider putting the source on [Github](https://www.github.com) and publishing your gem to [Rubygems](http://guides.rubygems.org/publishing/).

## Creating Gem Based Tools

Creating a gem based tool is very similar to creating a gem based target.   However, generally it will need to be done outside of your COSMOS project folder otherwise careful crafting in the "files" section of the gemspec file is required.
In general, you will need to create a cosmos-xxxxxx.gemspec (replace xxxxxx with your tool name) file and a directory structure like this:

{% highlight bash %}

├── cosmos-xxxxxx.gemspec
├── config
|  └── data
|   |   └── xxxxxx.png # Tool icon
├── lib
|  └── # Tool code files
├── tools
   └── Xxxxxx # Tool starting script (see Launcher, etc)
   └── mac
      └── Xxxxxx # Mac Tool starting script (see Launcher.app, etc)

{% endhighlight %}

The gem name must start with "cosmos-", and should then be followed by the actual tool name.  For example: cosmos-satvis.gemspec could be the gem name for a tool called Satvis.

Example cosmos-xxxxxx.gemspec file for a tool:

{% highlight ruby %}
# encoding: ascii-8bit

require 'rbconfig'

# Create the overall gemspec
spec = Gem::Specification.new do |s|
  s.name = 'cosmos-xxxxxx' # UPDATE WITH YOUR GEM NAME (must start with cosmos-)
  s.summary = 'Ball Aerospace COSMOS based tool' # UPDATE
  s.description =  <<-EOF
    Example gem based tool # UPDATE
  EOF
  s.authors = ['Your Name'] # UPDATE
  s.email = ['yourname@yourcompany.com'] # UPDATE

  s.platform = Gem::Platform::RUBY
  if ENV['VERSION']
    s.version = ENV['VERSION'].dup
  else
    s.version = '0.0.0'
  end
  s.license = 'GPL-3.0' # UPDATE

  # Modify as needed
  s.files = Dir['config/data/*'] + Dir['lib/*'] + Dir['tools/**/*']

  s.has_rdoc = true

  s.required_ruby_version = '~> 2'

  # Runtime Dependencies
  s.add_runtime_dependency 'cosmos', '~> 3', '>= 3.7.0'
end

{% endhighlight %}

After organizing the files as required and creating the gemspec, create the actual gem with the following:

{% highlight bash %}
# Windows - update VERSION as needed
set VERSION=1.0.0
gem build cosmos-xxxxxx.gemspec

# Linux/Mac - update VERSION as needed
export VERSION=1.0.0
gem build cosmos-xxxxxx.gemspec
{% endhighlight %}

To publish your gem for other COSMOS users consider putting the source on [Github](https://www.github.com) and publishing your gem to [Rubygems](http://guides.rubygems.org/publishing/).
