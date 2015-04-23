:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Installs Ball Aerospace COSMOS on Windows 7+
:: Usage: INSTALL_COSMOS [Install Directory] [COSMOS Version] 
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
set START_PATH=!PATH!

:: Change Protocol to http if you have SSL issues
set PROTOCOL=https

:: Update this version if making any changes to this script
set INSTALLER_VERSION=1.0

:: Paths and versions for COSMOS dependencies
set RUBY_INSTALLER_32=rubyinstaller-2.2.2.exe
set RUBY_INSTALLER_64=rubyinstaller-2.2.2-x64.exe
set RUBY_INSTALLER_PATH=//dl.bintray.com/oneclick/rubyinstaller/
set RUBY_ABI_VERSION=2.2.0
set DEVKIT_32=DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe
set DEVKIT_64=DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe
set WKHTMLTOPDF=wkhtmltox-0.11.0_rc1-installer.exe
set WKHTMLPATH=//downloads.sourceforge.net/project/wkhtmltopdf/old-archive/windows/
set QT_VERSION=4.8.6

http://downloads.sourceforge.net/project/wkhtmltopdf/old-archive/windows/wkhtmltox-0.11.0_rc1-installer.exe?r=http%3A%2F%2Fwkhtmltopdf.org%2Fold-downloads.html&ts=1429816951&use_mirror=hivelocity

::::::::::::::::::::::
:: Parse Parameters
::::::::::::::::::::::

IF [%1]==[] (
  set /p COSMOS_INSTALL="Enter COSMOS Install Directory: "
) else (
  set COSMOS_INSTALL=%~1
)
if not "!COSMOS_INSTALL!"=="!COSMOS_INSTALL: =!" (
  echo ERROR: Installation folder must not include spaces: "!COSMOS_INSTALL!"
  goto :END
)

IF [%2]==[] (
  set COSMOS_VERSION="LATEST"
) else (
  set COSMOS_VERSION=%~1
)
echo Using Ball Aerospace COSMOS Version !COSMOS_VERSION!

::::::::::::::::::::::::::::::::::
:: Create Installation Folder
::::::::::::::::::::::::::::::::::

IF EXIST !COSMOS_INSTALL! (
  set /p COSMOS_CONTINUE="Warning: Install Directory already exists. Continue? [y/N]: "
  IF NOT "!COSMOS_CONTINUE!"=="y" (
    echo Install Canceled
    GOTO END
  )
) else (
  :: Create the installation folder
  mkdir !COSMOS_INSTALL!
)
mkdir !COSMOS_INSTALL!\tmp > nul 2>&1
@echo COSMOS Windows Installer Version !INSTALLER_VERSION! > !COSMOS_INSTALL!\INSTALLER_VERSION.txt

::::::::::::::::::::::::
:: Install Ruby
::::::::::::::::::::::::

if %PROCESSOR_ARCHITECTURE%==x86 (
  IF NOT EXIST "!COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_32!" (
    echo Downloading 32-bit Ruby
    powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_32!', '!COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_32!')"
  )
  echo Installing 32-bit Ruby
  !COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_32! /silent /dir="!COSMOS_INSTALL!\Vendor\Ruby"
) else (
  IF NOT EXIST "!COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_64!" (
    echo Downloading 64-bit Ruby
    powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_64!', '!COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_64!')"
  )
  echo Installing 64-bit Ruby
  !COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_64! /silent /dir="!COSMOS_INSTALL!\Vendor\Ruby"
)

::::::::::::::::::::::::
:: Install Devkit
::::::::::::::::::::::::

if %PROCESSOR_ARCHITECTURE%==x86 (
  IF NOT EXIST "!COSMOS_INSTALL!\tmp\!DEVKIT_32!" (
    echo Downloading 32-bit DevKit
    powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!RUBY_INSTALLER_PATH!!DEVKIT_32!', '!COSMOS_INSTALL!\tmp\!DEVKIT_32!')"
  )
  echo Installing 32-bit DevKit
  !COSMOS_INSTALL!\tmp\!DEVKIT_32! -y -ai -gm2 -o"!COSMOS_INSTALL!\Vendor\Devkit"
) else (
  IF NOT EXIST "!COSMOS_INSTALL!\tmp\!DEVKIT_64!" (
    echo Downloading 64-bit DevKit
    powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!RUBY_INSTALLER_PATH!!DEVKIT_64!', '!COSMOS_INSTALL!\tmp\!DEVKIT_64!')"
  )
  echo Installing 64-bit DevKit
  !COSMOS_INSTALL!\tmp\!DEVKIT_64! -y -ai -gm2 -o"!COSMOS_INSTALL!\Vendor\Devkit"
)

::::::::::::::::::::::::
:: Install WkHtmlToPdf
::::::::::::::::::::::::

IF NOT EXIST "!COSMOS_INSTALL!\tmp\!WKHTMLTOPDF!" (
  echo Downloading WkHtmlToPdf
  powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!WKHTMLPATH!!WKHTMLTOPDF!', '!COSMOS_INSTALL!\tmp\!WKHTMLTOPDF!')"
)
echo Installing WkHtmlToPdf
!COSMOS_INSTALL!\tmp\!WKHTMLTOPDF! /S /D=!COSMOS_INSTALL!\Vendor\wkhtmltopdf

::::::::::::::::::::::::::::::::::::::::::::
:: Setup gemrc to use the correct protocol
::::::::::::::::::::::::::::::::::::::::::::

mkdir !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc > nul 2>&1
@echo --- > !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc
@echo :backtrace: false >> !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc
@echo :benchmark: false >> !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc
@echo :bulk_threshold: 1000 >> !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc
@echo :sources: >> !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc
@echo - !PROTOCOL!://rubygems.org/ >> !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc
@echo :update_sources: true >> !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc
@echo :verbose: true >> !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Download and unzip additional files needed for the installation
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

IF NOT EXIST "!COSMOS_INSTALL!\tmp\COSMOS_Windows_Install.zip" (
  echo Downloading COSMOS_Windows_Install.zip
  powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!://github.com/BallAerospace/COSMOS/blob/master/vendor/installers/windows/COSMOS_Windows_Install.zip?raw=true', '!COSMOS_INSTALL!\tmp\COSMOS_Windows_Install.zip')"
)
@echo Set ArgObj = WScript.Arguments > !COSMOS_INSTALL!\tmp\unzip.vbs
@echo strFileZIP = ArgObj(0) >> !COSMOS_INSTALL!\tmp\unzip.vbs
@echo outFolder = ArgObj(1) ^& "\" >> !COSMOS_INSTALL!\tmp\unzip.vbs
@echo WScript.Echo ("Extracting file " ^& strFileZIP ^& " to " ^& outFolder) >> !COSMOS_INSTALL!\tmp\unzip.vbs
@echo Set objShell = CreateObject( "Shell.Application" ) >> !COSMOS_INSTALL!\tmp\unzip.vbs 
@echo Set objSource = objShell.NameSpace(strFileZIP).Items() >> !COSMOS_INSTALL!\tmp\unzip.vbs 
@echo Set objTarget = objShell.NameSpace(outFolder) >> !COSMOS_INSTALL!\tmp\unzip.vbs 
@echo intOptions = 256 >> !COSMOS_INSTALL!\tmp\unzip.vbs 
@echo objTarget.CopyHere objSource, intOptions >> !COSMOS_INSTALL!\tmp\unzip.vbs 
cscript //B !COSMOS_INSTALL!\tmp\unzip.vbs !COSMOS_INSTALL!\tmp\COSMOS_Windows_Install.zip !COSMOS_INSTALL!

::::::::::::::::::::::::::::
:: Install Gems
::::::::::::::::::::::::::::

:: Set environmental variables
SET "GEM_HOME=!COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\!RUBY_ABI_VERSION!"
SET "GEM_PATH=%GEM_HOME%"
SET "GEMRC=!COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc"

:: Prepend embedded bin to PATH so we prefer those binaries
SET RI_DEVKIT=!COSMOS_INSTALL!\Vendor\Devkit\
SET "PATH=!COSMOS_INSTALL!\Vendor\Ruby\bin;%RI_DEVKIT%bin;%RI_DEVKIT%mingw\bin;%PATH%"

:: Remove RUBYOPT and RUBYLIB, which can cause serious problems.
SET RUBYOPT=
SET RUBYLIB=

:: update rubygems to latest (workaround issue installing pry)
call gem update --system 2.4.4
call gem install pry -v 0.10.1
call gem update --system

:: install COSMOS gem and dependencies
echo Installing COSMOS gem !COSMOS_VERSION!...
if !COSMOS_VERSION!=="LATEST" (
  call gem install cosmos
) else (
  call gem install cosmos -v !COSMOS_VERSION!
)

:: move qt dlls to the ruby/bin folder - prevents conflicts with other versions of qt on the system
if %PROCESSOR_ARCHITECTURE%==x86 (
  move !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\!RUBY_ABI_VERSION!\gems\qtbindings-qt-!QT_VERSION!-x86-mingw32\qtbin\*.dll !COSMOS_INSTALL!\Vendor\Ruby\bin
) else (
  move !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\!RUBY_ABI_VERSION!\gems\qtbindings-qt-!QT_VERSION!-x64-mingw32\qtbin\*.dll !COSMOS_INSTALL!\Vendor\Ruby\bin
)

:::::::::::::::::::::
:: Setup demo areas
:::::::::::::::::::::

call cosmos install !COSMOS_INSTALL!\Basic
call cosmos demo !COSMOS_INSTALL!\Demo

::::::::::::::::::::::::::
:: Desktop Icon
::::::::::::::::::::::::::

@echo Set oWS = WScript.CreateObject("WScript.Shell") > !COSMOS_INSTALL!\tmp\makeshortcut.vbs
@echo sLinkFile = "!USERPROFILE!\Desktop\COSMOS.lnk" >> !COSMOS_INSTALL!\tmp\makeshortcut.vbs
@echo Set oLink = oWS.CreateShortcut(sLinkFile) >> !COSMOS_INSTALL!\tmp\makeshortcut.vbs
@echo oLink.TargetPath = "!COSMOS_INSTALL!\LAUNCH_DEMO.bat" >> !COSMOS_INSTALL!\tmp\makeshortcut.vbs
@echo oLink.IconLocation = "!COSMOS_INSTALL!\cosmos_icon.ico" >> !COSMOS_INSTALL!\tmp\makeshortcut.vbs
@echo oLink.Save >> !COSMOS_INSTALL!\tmp\makeshortcut.vbs
set /p COSMOS_CONTINUE="Create Desktop Shortcut? [Y/n]: "
IF NOT "!COSMOS_CONTINUE!"=="n" (
  cscript //B !COSMOS_INSTALL!\tmp\makeshortcut.vbs
)

::::::::::::::::::::::::::
:: Environment Variables 
::::::::::::::::::::::::::

set /p COSMOS_CONTINUE="Set COSMOS_DIR Environment Variable? [Y/n]: "
IF NOT "!COSMOS_CONTINUE!"=="n" (
  setx COSMOS_DIR "!COSMOS_INSTALL!"
  echo COSMOS_DIR set for Current User. 
  echo Add System Environment Variable if desired for all users.
)

::::::::::::::::::::::::::::::::::::::::::
:: Test Installation by Launching COSMOS
::::::::::::::::::::::::::::::::::::::::::

start !COSMOS_INSTALL!\Launch_Demo.bat
echo COSMOS Launcher should start if installation was successful

:END
ENDLOCAL
echo Done
