---
layout: docs_v4
title: Contributing
---

So you've got an awesome idea to throw into COSMOS. Great! This is the basic process:

1. Fork the project on Github
1. Create a feature branch
1. Make your changes
1. Submit a pull request

<div class="note">
  <h5>Don't Forget the Contributor License Agreement!</h5>
  <p>
Before any contributions can be incorporated we do require all contributors to sign a Contributor License Agreement here: <a href="https://docs.google.com/forms/d/1ppnHUSXtY1GRTNPIyUaB1OYHbW5Ca67GFMgMRPBG8u0/viewform">Contributor License Agreement</a>

This protects both you and us and you retain full rights to any code you write.

  </p>
</div>

## Test Dependencies

To run the test suite and build the gem you'll need to install COSMOS's
dependencies. COSMOS uses Bundler, so a quick run of the `bundle` command and
you're all set!

{% highlight bash %}
\$ bundle
{% endhighlight %}

Before you start, run the tests and make sure that they pass (to confirm your
environment is configured properly):

{% highlight bash %}
\$ bundle exec rake build spec
{% endhighlight %}

## Workflow

Here's the most direct way to get your work merged into the project:

- Fork the project.
- Clone down your fork:

{% highlight bash %}
git clone git://github.com/<username>/COSMOS.git
{% endhighlight %}

- Create a topic branch to contain your change:

{% highlight bash %}
git checkout -b my_awesome_feature
{% endhighlight %}

- Hack away, add tests. Not necessarily in that order.
- Make sure everything still passes by running `bundle exec rake`.
- If necessary, rebase your commits into logical chunks, without errors.
- Push the branch up:

{% highlight bash %}
git push origin my_awesome_feature
{% endhighlight %}

- Create a pull request against BallAerospace/COSMOS:master and describe what your
  change does and the why you think it should be merged.

<div class="note">
  <h5>Let us know what could be better!</h5>
  <p>
    Both using and hacking on COSMOS should be fun, simple, and easy, so if for
    some reason you find it's a pain, please <a
    href="{{ site.repository }}/issues/new">create an issue</a> on
    GitHub describing your experience so we can make it better.
  </p>
</div>
