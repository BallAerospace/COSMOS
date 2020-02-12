---
layout: docs
title: Directory structure
permalink: /docs/structure/
---

Configuring COSMOS for your hardware unlocks all of its functionality for your system.

COSMOS Configuration is organized into the following directory structure with all files having a well defined location:

{% highlight bash %}
.
├── Gemfile
├── Launcher
├── Launcher.bat
├── Rakefile
├── config
|   ├── dart (optional)
|   ├── data
|   ├── system
|   ├── targets
|   |   ├── TARGET
|   |   |   ├── cmd_tlm
|   |   |   ├── lib
|   |   |   ├── procedures
|   |   |   ├── screens
|   |   |   ├── sequences
|   |   |   ├── tables
|   |   |   ├── tools
|   |   |   |   ├── table_manager
|   |   |   |   └── ...
|   |   |   ├── cmd_tlm_server.txt
|   |   |   └── target.txt
|   |   └── ...
|   └── tools
|   |   ├── cmd_tlm_server
|   |   └── ...
├── lib
├── outputs
|   ├── dart (optional)
|   ├── handbooks
|   ├── logs
|   ├── saved_config
|   ├── sequences
|   ├── tables
|   └── tmp
├── procedures
├── tools
|   ├── mac
|   └── ...
{% endhighlight %}

An overview of what each of these does:

<div class="mobile-side-scroller">
<table>
  <thead>
    <tr><th>File / Directory</th><th>Description</th></tr>
  </thead>
  <tbody>

    <tr>
      <td><p><code class="wrap">Gemfile</code></p></td>
      <td><p>
        Defines the gems and their versions used by your COSMOS configuration.
        If you want to use other gems in your cosmos project you should add them here
        and then run "bundle install" from the command line. See the <a href="http://bundler.io/">Bundler</a>
        documents and our <a href="/docs/upgrading">Upgrading</a> section for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">Launcher</code></p></td>
      <td><p>
        A small script used to launch the COSMOS Launcher application. <code>ruby Launcher</code>
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">Launcher.bat</code></p></td>
      <td><p>
        Windows batch file used to launch the COSMOS Launcher application from Windows explorer.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">Rakefile</code></p></td>
      <td><p>
        The Rakefile contains user modifiable scripts to perform common tasks using the ruby <code>rake</code> application. By default it comes with a script that is used to calculate CRCs over the project's files. <code>rake crc</code>
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config</code></p></td>
      <td><p>
        The config folder contains all of the configuration necessary for a COSMOS project.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ dart</code></p></td>
      <td><p>
        The config/dart folder contains the DART Gemfile along with any other configuration files needed by the <a href="/docs/dart_overview">DART</a> application.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ data</code></p></td>
      <td><p>
        The config/data folder contains data shared between applications such as images. It also contains the crc.txt file that holds the expected CRCs for each of the configurations files.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ system</code></p></td>
      <td><p>
        The config/system folder contains system.txt one of the first files you may need to edit for you COSMOS configuration. <code>system.txt</code> contains settings common to all of the COSMOS applications. It is also defines the targets that make up your COSMOS configuration. See <a href="/docs/system">System Configuration</a> for all the details.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets</code></p></td>
      <td><p>
        The config/targets folder contains the configuration for each target that is to be commanded or receive telemetry (data) from in a COSMOS configuration. Target folders should be named after the name of the target and be ALL CAPS.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET</code></p></td>
      <td><p>
        config/targets/TARGET folders contains the configuration for a target that is to be commanded or receive telemetry (data) from in a COSMOS configuration. Target folders should be named after the name of the target and be ALL CAPS.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ cmd_tlm</code></p></td>
      <td><p>
        config/targets/TARGET/cmd_tlm contains command and telemetry definition files for the target. See <a href="/docs/command">Command</a> and <a href="/docs/telemetry">Telemetry</a> Configuration for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ lib</code></p></td>
      <td><p>
        config/targets/TARGET/lib contains any custom code required by the target. Often this includes a custom Interface class. See <a href="/docs/interfaces">Interfaces</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ procedures</code></p></td>
      <td><p>
        config/targets/TARGET/procedures contains target specific procedures which exercise functionality of the target. These procedures should be kept simple and only use the command and telemetry definitions associated with this target. See the <a href="/docs/scripting">Scripting Guide</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ screens</code></p></td>
      <td><p>
        config/targets/TARGET/screens contains telemetry screens for the target. See <a href="/docs/screens">Screen Configuration</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ sequences</code></p></td>
      <td><p>
        config/targets/TARGET/sequences contains command sequences for the target. These are specific files used by the COSMOS Command Sequence tool.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ tables</code></p></td>
      <td><p>
        config/targets/TARGET/tables contains binary tables for the target. These are specific files used by the COSMOS Table Manager tool.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ tools</code></p></td>
      <td><p>
        config/targets/TARGET/tools contains target specific configuration files for the COSMOS applications. Most tools support configuration but do not require it.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ cmd_tlm_server.txt</code></p></td>
      <td><p>
        config/targets/TARGET/cmd_tlm_server.txt contains a snippet of the configuration for the COSMOS Command and Telemetry Server that defines how to interface with the specific target. See <a href="/docs/interfaces">Interface Configuration</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ targets/ TARGET/ target.txt</code></p></td>
      <td><p>
        config/targets/TARGET/target.txt contains target specific configuration such as which command parameters should be ignored by Command Sender. See <a href="/docs/system/#target-configuration">Target Configuration</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ tools</code></p></td>
      <td><p>
        config/tools contains configuration files for the COSMOS applications. Most tools support configuration but do not require it. See <a href="/docs/tools">Tool Configuration</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">config/ tools/ cmd_tlm_server</code></p></td>
      <td><p>
        config/tools/cmd_tlm_server contains the configuration file for the COSMOS Command and Telemetry Server (by default cmd_tlm_server.txt). This file defines how to connect to each target in the COSMOS configuration. See <a href="/docs/system">System Configuration</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">lib</code></p></td>
      <td><p>
        The lib folder contains shared custom code written for the COSMOS configuration. This is also the place to override default COSMOS functionality. To do this you need to mirror the COSMOS directly structure and naming. First create a 'cosmos' directory and then add sub-folders and files which mirror the <a href="https://github.com/BallAerospace/COSMOS/tree/master/lib/cosmos">COSMOS source</a>.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs</code></p></td>
      <td><p>
        The outputs folder contains all files generated by COSMOS applications.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs/ dart</code></p></td>
      <td><p>
        The outputs/dart folder contains the data and logs directories which DART uses to log the incoming command and telemetry data and log DART application status.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs/ handbooks</code></p></td>
      <td><p>
        The outputs/handbooks folder contains command and telemetry handbooks generated by Handbook Creator.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs/ logs</code></p></td>
      <td><p>
        The outputs/logs folder contains packet and message logs.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs/ saved_config</code></p></td>
      <td><p>
        The outputs/saved_config folder contains configuration saved by COSMOS. Every time COSMOS runs it saves the current configuration into this folder. Saved configurations are used to enable reading back old packet log files that may have been generated with a different packet configuration than the current configuration. If you are running in production and collecting results these configurations should be saved (configuration managed) so you can re-parse the binary log data collected.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs/ sequences</code></p></td>
      <td><p>
        The outputs/sequences folder contains sequence files generated by Command Sequence.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs/ tables</code></p></td>
      <td><p>
        The outputs/tables folder contains table files generated by Table Manager.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">outputs/ tmp</code></p></td>
      <td><p>
        The outputs/tmp folder contains temporary files generated by the COSMOS tools. These are typically cache files to improve performance. They may be safely deleted at any time.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">procedures</code></p></td>
      <td><p>
        The procedures folder is the default location for storing COSMOS test and operations procedures. See the <a href="/docs/scripting">Scripting Guide</a> for more information.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">tools</code></p></td>
      <td><p>
        The tools folder contains the scripts used to launch each of the COSMOS tools.
      </p></td>
    </tr>

    <tr>
      <td><p><code class="wrap">tools/ mac</code></p></td>
      <td><p>
        The tools/mac folder contains Mac application bundles used to launch the COSMOS tools on Mac computers.
      </p></td>
    </tr>

  </tbody>
</table>
</div>
