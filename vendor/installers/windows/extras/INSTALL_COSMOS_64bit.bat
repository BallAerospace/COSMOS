:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Installs Ball Aerospace COSMOS on Windows 7+
:: Usage: INSTALL_COSMOS [Install Directory] [COSMOS Version]
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
set START_PATH=!PATH!

:: Change Protocol to http if you have SSL issues
set PROTOCOL=https

:: Update this version if making any changes to this script
set INSTALLER_VERSION=1.4

:: Paths and versions for COSMOS dependencies
set RUBY_INSTALLER_32=rubyinstaller-2.2.3.exe
set RUBY_INSTALLER_64=rubyinstaller-2.2.3-x64.exe
set RUBY_INSTALLER_PATH=//dl.bintray.com/oneclick/rubyinstaller/
set RUBY_ABI_VERSION=2.2.0
set DEVKIT_32=DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe
set DEVKIT_64=DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe
set WKHTMLTOPDF=wkhtmltox-0.11.0_rc1-installer.exe
set WKHTMLPATHWITHPROTOCOL=http://download.gna.org/wkhtmltopdf/obsolete/windows/
set QTBINDINGS_QT_VERSION=4.8.6.3

:: Detect Ball
if "%USERDNSDOMAIN%"=="AERO.BALL.COM" (
  set BALL=1
) else (
  set BALL=0
)

:: Detect if SSL_CERT_FILE is set
if not defined SSL_CERT_FILE (
  if !BALL!==1 (
    echo WARNING: Using http at Ball because SSL_CERT_FILE is not set
    pause
    set PROTOCOL=http
  )
)

:: Detect if user is an admin
%SYSTEMROOT%\System32\whoami /groups | %SYSTEMROOT%\System32\find "S-1-5-32-544" > nul
if not errorlevel 1 (
  set ADMIN=1
) else (
  set ADMIN=0
)

:: Detect if any gem files are present in current folder
if exist *.gem (
  echo WARNING: gem files found in the current directory
  echo WARNING: This can cause the installation to fail or install old gems
  pause  
)

::::::::::::::::::::::
:: Parse Parameters
::::::::::::::::::::::

IF [%1]==[] (
  set /p COSMOS_INSTALL="Enter COSMOS Install Directory as an absolute path [C:\COSMOS]: "
  IF "!COSMOS_INSTALL!"=="" (
    set COSMOS_INSTALL=C:\COSMOS
  )
) else (
  set COSMOS_INSTALL=%~1
)
if not "!COSMOS_INSTALL!"=="!COSMOS_INSTALL: =!" (
  echo ERROR: Installation folder must not include spaces: "!COSMOS_INSTALL!"
  echo INSTALL FAILED
  pause
  exit /b 1
)
set COSMOS_INSTALL_FORWARD=%COSMOS_INSTALL:\=/%

IF [%2]==[] (
  set COSMOS_VERSION="LATEST"
) else (
  set COSMOS_VERSION=%~2
)
echo Using Ball Aerospace COSMOS Version !COSMOS_VERSION!

::::::::::::::::::::::::::::::::::
:: Create Installation Folder
::::::::::::::::::::::::::::::::::

IF EXIST !COSMOS_INSTALL! (
  echo ERROR: Installation folder already exists: "!COSMOS_INSTALL!"
  echo INSTALL FAILED
  pause
  exit /b 1
) else (
  :: Create the installation folder
  mkdir !COSMOS_INSTALL!
  if errorlevel 1 (
    echo ERROR: Failed to create directory: "!COSMOS_INSTALL!"
    echo INSTALL FAILED
    pause
    exit /b 1
  )
)
mkdir !COSMOS_INSTALL!\tmp > nul 2>&1
if errorlevel 1 (
  echo ERROR: Failed to create directory: "!COSMOS_INSTALL!\tmp"
  echo INSTALL FAILED
  pause
  exit /b 1
)

::::::::::::::::::::::::::::::::::::::::
:: Log our settings to the INSTALL.log
::::::::::::::::::::::::::::::::::::::::

@echo COSMOS Windows Installer Version !INSTALLER_VERSION! > !COSMOS_INSTALL!\INSTALL.log
@echo Installing to: !COSMOS_INSTALL! >> !COSMOS_INSTALL!\INSTALL.log
@echo COSMOS_VERSION=!COSMOS_VERSION! >> !COSMOS_INSTALL!\INSTALL.log
@echo PATH=!START_PATH! >> !COSMOS_INSTALL!\INSTALL.log
@echo PROTOCOL=!PROTOCOL! >> !COSMOS_INSTALL!\INSTALL.log
@echo RUBY_INSTALLER_32=!RUBY_INSTALLER_32! >> !COSMOS_INSTALL!\INSTALL.log
@echo RUBY_INSTALLER_64=!RUBY_INSTALLER_64! >> !COSMOS_INSTALL!\INSTALL.log
@echo RUBY_INSTALLER_PATH=!RUBY_INSTALLER_PATH! >> !COSMOS_INSTALL!\INSTALL.log
@echo RUBY_ABI_VERSION=!RUBY_ABI_VERSION! >> !COSMOS_INSTALL!\INSTALL.log
@echo DEVKIT_32=!DEVKIT_32! >> !COSMOS_INSTALL!\INSTALL.log
@echo DEVKIT_64=!DEVKIT_64! >> !COSMOS_INSTALL!\INSTALL.log
@echo WKHTMLTOPDF=!WKHTMLTOPDF! >> !COSMOS_INSTALL!\INSTALL.log
@echo WKHTMLPATHWITHPROTOCOL=!WKHTMLPATHWITHPROTOCOL! >> !COSMOS_INSTALL!\INSTALL.log
@echo QTBINDINGS_QT_VERSION=!QTBINDINGS_QT_VERSION! >> !COSMOS_INSTALL!\INSTALL.log
@echo USERDNSDOMAIN=%USERDNSDOMAIN% >> !COSMOS_INSTALL!\INSTALL.log
@echo BALL=!BALL! >> !COSMOS_INSTALL!\INSTALL.log
@echo SSL_CERT_FILE=%SSL_CERT_FILE% >> !COSMOS_INSTALL!\INSTALL.log
@echo ADMIN=!ADMIN! >> !COSMOS_INSTALL!\INSTALL.log
@echo PROCESSOR_ARCHITECTURE=%PROCESSOR_ARCHITECTURE% >> !COSMOS_INSTALL!\INSTALL.log
@echo. >> !COSMOS_INSTALL!\INSTALL.log

::::::::::::::::::::::::
:: Install Ruby
::::::::::::::::::::::::

  echo Downloading 64-bit Ruby
  powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_64!', '!COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_64!')"
  if errorlevel 1 (
    echo ERROR: Problem downloading 64-bit Ruby from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_64!
    echo INSTALL FAILED
    @echo ERROR: Problem downloading 64-bit Ruby from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_64! >> !COSMOS_INSTALL!\INSTALL.log
    pause
    exit /b 1
  ) else (
    @echo Successfully downloaded 64-bit Ruby from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_64! >> !COSMOS_INSTALL!\INSTALL.log
  )
  echo Installing 64-bit Ruby
  !COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_64! /silent /dir="!COSMOS_INSTALL!\Vendor\Ruby"
  if errorlevel 1 (
    echo ERROR: Problem installing 64-bit Ruby
    echo INSTALL FAILED
    @echo ERROR: Problem installing 64-bit Ruby >> !COSMOS_INSTALL!\INSTALL.log
    pause
    exit /b 1
  ) else (
    @echo Successfully installed 64-bit Ruby >> !COSMOS_INSTALL!\INSTALL.log
  )

::::::::::::::::::::::::
:: Install Devkit
::::::::::::::::::::::::

  echo Downloading 64-bit DevKit
  powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!RUBY_INSTALLER_PATH!!DEVKIT_64!', '!COSMOS_INSTALL!\tmp\!DEVKIT_64!')"
  if errorlevel 1 (
    echo ERROR: Problem downloading 64-bit Devkit from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!DEVKIT_64!
    echo INSTALL FAILED
    @echo ERROR: Problem downloading 64-bit Devkit from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!DEVKIT_64! >> !COSMOS_INSTALL!\INSTALL.log
    pause
    exit /b 1
  ) else (
    @echo Successfully downloaded 64-bit Devkit from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!DEVKIT_64! >> !COSMOS_INSTALL!\INSTALL.log
  )
  echo Installing 64-bit DevKit
  !COSMOS_INSTALL!\tmp\!DEVKIT_64! -y -ai -gm2 -o"!COSMOS_INSTALL!\Vendor\Devkit"
  if errorlevel 1 (
    echo ERROR: Problem installing 64-bit Devkit
    echo INSTALL FAILED
    @echo ERROR: Problem installing 64-bit Devkit >> !COSMOS_INSTALL!\INSTALL.log
    pause
    exit /b 1
  ) else (
    @echo Successfully installed 64-bit Devkit >> !COSMOS_INSTALL!\INSTALL.log
  )

::::::::::::::::::::::::
:: Install WkHtmlToPdf
::::::::::::::::::::::::

if !ADMIN!==1 (
  echo Downloading WkHtmlToPdf
  powershell -Command "(New-Object Net.WebClient).DownloadFile('!WKHTMLPATHWITHPROTOCOL!!WKHTMLTOPDF!', '!COSMOS_INSTALL!\tmp\!WKHTMLTOPDF!')"
  if errorlevel 1 (
    echo WARNING: Problem downloading WkHtmlToPdf from: !WKHTMLPATHWITHPROTOCOL!!WKHTMLTOPDF!
    echo Please download and install this version to enable making PDF files.
    echo INSTALL WARNING
    @echo WARNING: Problem downloading WkHtmlToPdf from: !WKHTMLPATHWITHPROTOCOL!!WKHTMLTOPDF! >> !COSMOS_INSTALL!\INSTALL.log
    pause
  ) else (
    @echo Successfully downloaded WkHtmlToPdf from: !WKHTMLPATHWITHPROTOCOL!!WKHTMLTOPDF! >> !COSMOS_INSTALL!\INSTALL.log
    echo Installing WkHtmlToPdf
    !COSMOS_INSTALL!\tmp\!WKHTMLTOPDF! /S /D=!COSMOS_INSTALL!\Vendor\wkhtmltopdf
    if errorlevel 1 (
      echo ERROR: Problem installing WkHtmlToPdf
      echo Please download and install this version to enable making PDF files.
      echo !WKHTMLPATHWITHPROTOCOL!!WKHTMLTOPDF!
      @echo ERROR: Problem installing WkHtmlToPdf >> !COSMOS_INSTALL!\INSTALL.log
    ) else (
      @echo Successfully installed WkHtmlToPdf >> !COSMOS_INSTALL!\INSTALL.log
    )
  )

) else (
  echo Skipping WkHtmlToPdf installation because you are not an admin.
  echo Please download and install this version to enable making PDF files.
  echo !WKHTMLPATHWITHPROTOCOL!!WKHTMLTOPDF!
  @echo Skipping WkHtmlToPdf installation because you are not an admin. >> !COSMOS_INSTALL!\INSTALL.log
  @echo Please download and install this version to enable making PDF files. >> !COSMOS_INSTALL!\INSTALL.log
  @echo !WKHTMLPATHWITHPROTOCOL!!WKHTMLTOPDF! >> !COSMOS_INSTALL!\INSTALL.log
)

::::::::::::::::::::::::::::::::::::::::::::
:: Setup gemrc to use the correct protocol
::::::::::::::::::::::::::::::::::::::::::::

mkdir !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc > nul 2>&1
if errorlevel 1 (
  echo ERROR: Failed to create directory: "!COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc"
  @echo ERROR: Failed to create directory: "!COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc" >> !COSMOS_INSTALL!\INSTALL.log
  echo INSTALL FAILED
  pause
  exit /b 1
)
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

echo Downloading COSMOS_Windows_Install.zip
powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!://github.com/BallAerospace/COSMOS/blob/master/vendor/installers/windows/COSMOS_Windows_Install.zip?raw=true', '!COSMOS_INSTALL!\tmp\COSMOS_Windows_Install.zip')"
if errorlevel 1 (
  echo ERROR: Problem downloading COSMOS Windows files from: !PROTOCOL!://github.com/BallAerospace/COSMOS/blob/master/vendor/installers/windows/COSMOS_Windows_Install.zip?raw=true
  echo INSTALL FAILED
  @echo ERROR: Problem downloading COSMOS Windows files from: !PROTOCOL!://github.com/BallAerospace/COSMOS/blob/master/vendor/installers/windows/COSMOS_Windows_Install.zip?raw=true >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully downloaded COSMOS Windows files from: !PROTOCOL!://github.com/BallAerospace/COSMOS/blob/master/vendor/installers/windows/COSMOS_Windows_Install.zip?raw=true >> !COSMOS_INSTALL!\INSTALL.log
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
if errorlevel 1 (
  echo ERROR: Problem unzipping COSMOS Windows files
  echo INSTALL FAILED
  @echo ERROR: Problem unzipping COSMOS Windows files >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully unzipped COSMOS Windows files >> !COSMOS_INSTALL!\INSTALL.log
)

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
if errorlevel 1 (
  echo ERROR: Problem updating gem to 2.4.4
  echo INSTALL FAILED
  @echo ERROR: Problem updating gem to 2.4.4 >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully updated gem to 2.4.4 >> !COSMOS_INSTALL!\INSTALL.log
)
call gem install pry -v 0.10.1
if errorlevel 1 (
  echo ERROR: Problem installing pry gem
  echo INSTALL FAILED
  @echo ERROR: Problem installing pry gem >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully installed pry gem >> !COSMOS_INSTALL!\INSTALL.log
)
call gem update --system 2.4.8
if errorlevel 1 (
  echo ERROR: Problem updating gem to 2.4.8
  echo INSTALL FAILED
  @echo ERROR: Problem updating gem to 2.4.8 >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully updated gem to latest >> !COSMOS_INSTALL!\INSTALL.log
)

:: install COSMOS gem and dependencies
echo Installing COSMOS gem !COSMOS_VERSION!...
if !COSMOS_VERSION!=="LATEST" (
  call gem install cosmos
) else (
  call gem install cosmos -v !COSMOS_VERSION!
)
if errorlevel 1 (
  echo ERROR: Problem installing cosmos gem
  echo INSTALL FAILED
  @echo ERROR: Problem installing cosmos gem >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully installed cosmos gem >> !COSMOS_INSTALL!\INSTALL.log
)

:: move qt dlls to the ruby/bin folder - prevents conflicts with other versions of qt on the system
  move !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\!RUBY_ABI_VERSION!\gems\qtbindings-qt-!QTBINDINGS_QT_VERSION!-x64-mingw32\qtbin\*.dll !COSMOS_INSTALL!\Vendor\Ruby\bin
if errorlevel 1 (
  echo ERROR: Problem moving qt dlls
  @echo ERROR: Problem moving qt dlls >> !COSMOS_INSTALL!\INSTALL.log
  pause
) else (
  @echo Successfully moved qt dlls >> !COSMOS_INSTALL!\INSTALL.log
)

:::::::::::::::::::::
:: Fix bin stubs to relative paths
:::::::::::::::::::::
@echo forward_directory = "!COSMOS_INSTALL_FORWARD!/Vendor/Ruby/bin" > !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo back_directory = "!COSMOS_INSTALL:\=\\!\\Vendor\\Ruby\\bin" >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo Dir.foreach(forward_directory) do ^|filename^| >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo   if (File.extname(filename).downcase == '.bat') >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo     print "Patching #{filename}" >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo     data = File.read(File.join(forward_directory, filename)) >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo     result = data.gsub^^!(back_directory + '\\', '') >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo     result2 = data.gsub^^!(forward_directory + '/', '') >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo     if result or result2 >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo       File.write(File.join(forward_directory, filename), data) >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo       puts ": patched" >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo     else >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo       puts ": no change needed" >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo     end >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo   end >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
@echo end >> !COSMOS_INSTALL!\tmp\fix_stubs.rb
ruby !COSMOS_INSTALL!\tmp\fix_stubs.rb
if errorlevel 1 (
  echo ERROR: Problem fixing ruby stubs
  @echo ERROR: Problem fixing ruby stubs >> !COSMOS_INSTALL!\INSTALL.log
  pause
) else (
  @echo Successfully fixed ruby stubs >> !COSMOS_INSTALL!\INSTALL.log
)

:::::::::::::::::::::
:: Setup demo areas
:::::::::::::::::::::

call cosmos install !COSMOS_INSTALL!\Basic
if errorlevel 1 (
  echo ERROR: Problem creating cosmos Basic
  echo INSTALL FAILED
  @echo ERROR: Problem creating cosmos Basic >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully created cosmos Basic >> !COSMOS_INSTALL!\INSTALL.log
)
call cosmos demo !COSMOS_INSTALL!\Demo
if errorlevel 1 (
  echo ERROR: Problem creating cosmos Demo
  echo INSTALL FAILED
  @echo ERROR: Problem creating cosmos Demo >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully created cosmos Demo >> !COSMOS_INSTALL!\INSTALL.log
)

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
  if errorlevel 1 (
    echo ERROR: Problem creating desktop shortcut
    @echo ERROR: Problem creating desktop shortcut >> !COSMOS_INSTALL!\INSTALL.log
    pause
  ) else (
    @echo Successfully created desktop shortcut >> !COSMOS_INSTALL!\INSTALL.log
  )
)

::::::::::::::::::::::::::
:: Environment Variables
::::::::::::::::::::::::::

set /p COSMOS_CONTINUE="Set COSMOS_DIR Environment Variable? [Y/n]: "
IF NOT "!COSMOS_CONTINUE!"=="n" (
  setx COSMOS_DIR "!COSMOS_INSTALL!"
  if errorlevel 1 (
    echo ERROR: Problem creating COSMOS_DIR environment variable
    @echo ERROR: Problem creating COSMOS_DIR environment variable >> !COSMOS_INSTALL!\INSTALL.log
    pause
  ) else (
    echo COSMOS_DIR set for Current User.
    echo Add System Environment Variable if desired for all users.
    @echo Successfully created COSMOS_DIR environment variable >> !COSMOS_INSTALL!\INSTALL.log
  )
)

::::::::::::::::::::::::::::::::::::::::::
:: Test Installation by Launching COSMOS
::::::::::::::::::::::::::::::::::::::::::

pushd !COSMOS_INSTALL!
SET COSMOS_DEVEL=
start !COSMOS_INSTALL!\Launch_Demo.bat
echo COSMOS Launcher should start if installation was successful
echo INSTALLATION COMPLETE
@echo INSTALLATION COMPLETE >> !COSMOS_INSTALL!\INSTALL.log

ENDLOCAL
