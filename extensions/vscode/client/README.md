# COSMOS for Visual Studio Code

This extension adds language support for COSMOS configuration files.

To identify COSMOS configuration files, this extension assumes that it adheres to the strict directure structure of COSMOS inside of a <Project_Dir> as shown below.

```
<Project_Dir>
|--Gemfile
|--Launcher
|--Launcher.bat
|--Rakefile
|--userpath.txt
|--config
|  |--data
|  |--system
|  |--targets
|  |  |--<TARGETNAME>
|  |  |  |--cmd_tlm_server.txt
|  |  |  |--target.txt
|  |  |  |--(cmdtlm or cmd_tlm)
|  |  |  |--lib
|  |  |  |--screens
|  |  |--...
|  |--tools
|  |  |--cmd_tlm_server
|  |  |--...
|--lib
|--outputs
|  |--handbooks
|  |--logs
|  |--saved_config
|  |--tables
|  |--tmp
|--procedures
|--tools
|  |--mac
|  |--...
```