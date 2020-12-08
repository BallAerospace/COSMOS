---
layout: docs
title: DART Installation
toc: true
---

1. DART requires at least COSMOS version 4.3.0 although you should always install the latest to get important bug fixes and feature updates. Install the latest COSMOS by running:
   ```
   bundle update cosmos
   ```
1. Install the PostgreSQL database. DART has been tested with both version 9.x and 10.x so we recommend the latest version unless you already have a 9.x instance. When installing PostgreSQL you must create an overall superuser with a username and password. Once you have PostgreSQL installed with the superuser created, follow the following steps to configure for DART. (Note that on linux you will need to install postgresql and the postgresql-server-dev (or equivalent) packages)
1. If you are upgrading an existing COSMOS project perform the following steps.
   1. Somewhere else on your computer create a new COSMOS demo project:
      ```
      cosmos demo demo
      ```
   1. Copy config/dart/Gemfile from the demo project to your COSMOS project
   1. Copy config/targets/DART from the demo project to your COSMOS project
   1. Add these lines to your config/system/system.txt file:
      ```
      DECLARE_TARGET DART
      LISTEN_HOST DART_STREAM 0.0.0.0 # 127.0.0.1 is more secure if you don't need external connections
      LISTEN_HOST DART_DECOM 0.0.0.0 # 127.0.0.1 is more secure if you don't need external connections
      CONNECT_HOST DART_STREAM 127.0.0.1
      CONNECT_HOST DART_DECOM 127.0.0.1
      PORT DART_STREAM 8777
      PORT DART_DECOM 8779
      PATH DART_DATA ./outputs/dart/data
      PATH DART_LOGS ./outputs/dart/logs
      ```
   1. Add the following line to config/tools/launcher.txt:
      ```
      TOOL "DART" "LAUNCH_TERMINAL Dart" "dart.png"
      ```
1. Ensure the following line is in your project's Gemfile:
   ```
   # Uncomment this line to add DART dependencies to your main Gemfile
   instance_eval File.read(File.join(__dir__, 'config/dart/Gemfile'))
   ```
1. Run the following command from your COSMOS project configuration directory (not C:/COSMOS which contains Demo & Vendor as that is the installation directory) to install all the ruby dependencies for DART.
   ```
   bundle install
   ```
1. In postgres, create a 'dart' user and password (with CREATEDB permissions), and both a 'dart' and 'darttest' database (owned by the dart user). The databases should be created with template0, LC_COLLATE 'C', LC_CTYPE 'C', and ENCODING 'SQL_ASCII'
   1. On windows use pgadmin
   2. Otherwise use the psql command line:
      ```
      psql postgres
      CREATE ROLE dart WITH LOGIN PASSWORD 'dart';
      ALTER ROLE dart CREATEDB;
      \q
      psql -U dart
      CREATE DATABASE dart TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C' ENCODING 'SQL_ASCII';
      CREATE DATABASE darttest TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C' ENCODING 'SQL_ASCII';
      \q
      ```
1. Create an environment variable on your system named DART_USERNAME and set it to 'dart'. Note you can change this username if necessary as long as the postgres username created above has the same name.
1. Create an environment variable on your system named DART_PASSWORD and set it to the password created earlier.
1. Create an environment variable on your system named DART_DB and set it to 'dart'. Note: You can use whatever name you want
1. Create an environment variable on your system named DART_TEST_DB and set it to 'darttest'. Note: You can use whatever name you want
1. Open a new shell (to get the newly created environment variables) and run the following command from your COSMOS project configuration directory (not C:/COSMOS which contains Demo & Vendor as that is the installation directory)
   ```
   bundle exec rake db:schema:load
   bundle exec rake db:seed
   ```

<div class="note warning">
  <h5>Other possible dependencies</h5>
  <p>Depending on your platform other packages may be required. In particular the latest version of Ubuntu 18.04 requires libpq-dev and nodejs.  Additionally you may need to edit pg_hba.conf and change from using the peer authentication method to md5 and restart postgres.</p>
</div>

At this point the DART database is configured and ready to import COSMOS telemetry. When you start the COSMOS Demo you should see the new DART button in the Utilities section. If you're upgrading from an older version of COSMOS simply add this line to your config/tools/launcher/launcher.txt file:

```
TOOL "DART" "LAUNCH_TERMINAL Dart" "dart.png"
```

Once you click the DART button you should see a new terminal open with the following:

```
2018/04/03 16:00:30.269  INFO: Starting database cleanup...
2018/04/03 16:00:30.269  INFO: Cleaning up SystemConfig...
2018/04/03 16:00:30.373  INFO: Marshal load success: C:/git/COSMOS/demo/outputs/tmp/marshal_fee3ac209980cc7440182adbd1ce7eda.bin
2018/04/03 16:00:30.377  INFO: Cleaning up PacketLog...
2018/04/03 16:00:30.385  INFO: Cleaning up PacketConfig...
2018/04/03 16:00:30.392  INFO: Cleaning up PacketLogEntry...
2018/04/03 16:00:30.396  INFO: Cleaning up Decommutation tables (tX_Y)...
2018/04/03 16:00:30.396  INFO: Cleaning up Reductions...
2018/04/03 16:00:30.397  INFO: Database cleanup complete!
2018/04/03 16:00:30.397  INFO: Dart starting each process...
2018/04/03 16:00:30.397  INFO: Starting: ruby C:/git/cosmos/lib/cosmos/dart/processes/dart_ingester.rb
2018/04/03 16:00:30.411  INFO: Starting: ruby C:/git/cosmos/lib/cosmos/dart/processes/dart_reducer.rb
2018/04/03 16:00:30.424  INFO: Starting: ruby C:/git/cosmos/lib/cosmos/dart/processes/dart_stream_server.rb
2018/04/03 16:00:30.438  INFO: Starting: ruby C:/git/cosmos/lib/cosmos/dart/processes/dart_decom_server.rb
2018/04/03 16:00:30.453  INFO: Starting: ruby C:/git/cosmos/lib/cosmos/dart/processes/dart_worker.rb 0 1
2018/04/03 16:00:30.478  INFO: Dart Monitoring processes...
```

This indicates that DART is now monitoring the Server waiting for packets. Note that sometimes it can take a while for output to appear in the window. If you now start the COSMOS Command and Telemetry Server, DART will start receiving and processing telemetry data.

By default, DART writes log files in the COSMOS outputs/dart/logs directory. This directory can be changed by setting DART_LOGS in the config/system/system.txt file. Log files are created for each of the DART processes and are written to continuously as DART processes data and responds to user requests. By default, DART creates binary log files in the outputs/dart/data directory. This directory can be changed by setting DART_DATA in the config/system/system.txt file.

<div class="note warning">
  <h5>Changing the DART Data File Directory</h5>
  <p>DART indexes the files in outputs/dart/data. If these files are moved DART can no longer access them when responding to a Stream Server request (from Replay or Data Viewer). DART will not permanently delete them unless you start DART with the '--force-cleanup' option. Using that option will permanently delete the files and their associated decommutated data in the database.</p>
</div>

<div class="note warning">
  <h5>Shutting Down DART</h5>
  <p>Always shutdown dart with Ctrl-C or a soft kill (kill -2).  A hard kill will usually require database cleanup on the next startup of DART.</p>
</div>
