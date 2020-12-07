---
layout: docs
title: Environment Variables
---

### Environment Variables Affecting Tool Execution

<table>
  <tr><th>Environment Variable</th><th>Description</th></tr>
  <tr><td>COSMOS_DIR</td><td>Windows Only.  Tells the Windows .bat launcher files where to find the COSMOS Installation of Ruby.  Typically set to C:\COSMOS.  Expects Vendor\Ruby to exist in the directory.  Is not used if Vendor\Ruby is found within two directories up of the executing .bat (typically within a COSMOS Installation)</td></tr>
  <tr><td>COSMOS_USERPATH</td><td>Allows scripts that run outside of your COSMOS project configuration folder to know where the project configuration folder is. Only needed if you plan on using scripts that rely on your project specific command/telemetry definitions or other configuration outside of the project folder.</td></tr>
  <tr><td>COSMOS_TEXT</td><td>Process to launch for COSMOS "Open in Text Editor" buttons.  Should be exactly what needs to be typed from a command line and expect a single argument of a quoted filename to open.</td></tr>
  <tr><td>RUBYLIB</td><td>Adds folders to the Ruby library search path.</td></tr>
  <tr><td>RUBYOPT</td><td>Always passes specific command line options to the ruby interpretor</td></tr>
  <tr><td>GEM_PATH</td><td>Provides one or more paths to where gems may reside</td></tr>
  <tr><td>GEM_HOME</td><td>Provides the location where gems will be installed</td></tr>
  <tr><td>VISUAL</td><td>Preferred text editor used on linux if COSMOS_TEXT is not defined and gedit is not present</td></tr>
  <tr><td>EDITOR</td><td>Text editor used on linux if COSMOS_TEXT is not defined, and VISUAL is not defined, and gedit is not present</td></tr>
  <tr><td>PATH</td><td>PATH controls what executables are available to COSMOS when it shells out to tools.  It also affects the dynamic library search on some platforms.</td></tr>
  <tr><td>SystemRoot</td><td>Windows Only. Used to know the windows installation folder.</td></tr>
</table>

### Environment Variables Only Affecting Development And Unit Testing

<table>
  <tr><th>Environment Variable</th><th>Description</th></tr>
  <tr><td>COSMOS_DEVEL</td><td>Path to a local COSMOS development area.  Overrides using the gem in Gemfiles.</td></tr>
  <tr><td>COSMOS_NO_SIMPLECOV</td><td>If defined runs unit tests without doing coverage.</td></tr>
  <tr><td>PROFILE</td><td>If defined runs unit tests with profiling</td></tr>
  <tr><td>BENCHMARK</td><td>If defined runs unit tests with benchmarking</td></tr>
  <tr><td>TRAVIS</td><td>Used to skip specific unit tests when running in the Travis environment</td></tr>
  <tr><td>APPVEYOR</td><td>Used to skip specific unit tests when running in the AppVeyor environment</td></tr>
  <tr><td>VERSION</td><td>Used to specify the COSMOS version of the gemspec and Rakefile when building COSMOS gems</td></tr>
</table>

### Environment Variables Set By COSMOS

<table>
  <tr><th>Environment Variable</th><th>Description</th></tr>
  <tr><td>COSMOS_LOGS_DIR</td><td>Set by COSMOS so that tools outside of COSMOS can know where they can put log files.  Specifically used by the SegFault catching code to capture segfault logs.</td></tr>
  <tr><td>COSMOS_USERPATH</td><td>Set by Launcher to whatever Launcher determined the COSMOS_USERPATH to be.  This ensures that all tools spawned by Launcher will user the same COSMOS_USERPATH</td></tr>
  <tr><td>PATH</td><td>COSMOS adds the COSMOS gem's bin folder to the beginning of the PATH.</td></tr>
</table>
