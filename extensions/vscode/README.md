# COSMOS for Visual Studio Code

This extension adds language support for COSMOS configuration files.

This extension currently only supports syntax highlighting.

To identify COSMOS configuration files, this extension assumes that a COSMOS directory exists inside of the <Project_Dir> and that it adheres to the strict directure structure of COSMOS as shown below.

```
<Project_Dir>
|--COSMOS
|  |--Gemfile
|  |--Launcher
|  |--Launcher.bat
|  |--Rakefile
|  |--userpath.txt
|  |--config
|  |  |--data
|  |  |--system
|  |  |--targets
|  |  |  |--<TARGETNAME>
|  |  |  |  |--cmd_tlm_server.txt
|  |  |  |  |--target.txt
|  |  |  |  |--(cmdtlm or cmd_tlm)
|  |  |  |  |--lib
|  |  |  |  |--screens
|  |  |  |--...
|  |  |--tools
|  |  |  |--cmd_tlm_server
|  |  |  |--...
|  |--lib
|  |--outputs
|  |  |--handbooks
|  |  |--logs
|  |  |--saved_config
|  |  |--tables
|  |  |--tmp
|  |--procedures
|  |--tools
|  |  |--mac
|  |  |--...
|--<other_proj_dirs>
```