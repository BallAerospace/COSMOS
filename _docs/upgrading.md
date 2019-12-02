---
layout: docs
title: Upgrading and the Gemfile
permalink: /docs/upgrading/
---

Upgrading COSMOS to the latest version is easy.   Every COSMOS project comes with what is called a Gemfile.   The Gemfile is used to track the library dependencies of your COSMOS project.
If your project requires a gem that is not a standard COSMOS dependency, be sure to add it to your Gemfile to track that it is a requirement of your project.  In any case, to upgrade to the latest
version of COSMOS all you need to do is run:

{% highlight bash %}
bundle update cosmos
{% endhighlight %}

And that should get the latest version installed (unless your Gemfile has locked COSMOS to a specific version).  After upgrading, you should also look at the [COSMOS release notes](/docs/history) to see if any other migration is required. If you would like to lock COSMOS (or any other gem) to a specific version, you can also do that with your Gemfile.   Here is an example Gemfile that
locks COSMOS to version 4.4.0, shows the ruby-termios gem requirement on non-windows systems, and also adds a project specific requirement for the sshkit gem.

```
gem 'cosmos', '4.4.0'
gem 'ruby-termios' if RbConfig::CONFIG['target_os'] !~ /mswin|mingw|cygwin/i
gem 'sshkit'
```

Finally, whenever you receive a new COSMOS project, running the following command will ensure you have everything you need installed to run that configuration.


{% highlight bash %}
bundle install
{% endhighlight %}

For more information on Gemfiles and managing dependencies for a COSMOS (or any other Ruby-based) project see the bundler documentation at:
[Bundler Docs](http://bundler.io)
