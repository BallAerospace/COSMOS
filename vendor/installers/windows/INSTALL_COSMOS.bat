:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Installs Ball Aerospace COSMOS on Windows 7+
:: Usage: INSTALL_COSMOS [Install Directory] [COSMOS Version]
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
set START_PATH=!PATH!

:: Change Protocol to http if you have SSL issues
set PROTOCOL=https

:: Change this line if you want to force an architecture
set ARCHITECTURE=%PROCESSOR_ARCHITECTURE%

:: Update this version if making any changes to this script
set INSTALLER_VERSION=1.6

:: Paths and versions for COSMOS dependencies
set RUBY_INSTALLER_32=rubyinstaller-2.4.2-2.exe
set RUBY_INSTALLER_64=rubyinstaller-2.4.2-2-x64.exe
set RUBY_INSTALLER_PATH=//github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.4.2-2/
set RUBY_ABI_VERSION=2.4.0
set WKHTMLTOPDF=wkhtmltox-0.11.0_rc1-installer.exe
set WKHTMLPATHWITHPROTOCOL=https://downloads.wkhtmltopdf.org/obsolete/windows/
set QTBINDINGS_QT_VERSION=4.8.6.4
set WINDOWS_INSTALL_ZIP=//github.com/BallAerospace/COSMOS/blob/master/vendor/installers/windows/COSMOS_Windows_Install.zip

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
@echo WKHTMLTOPDF=!WKHTMLTOPDF! >> !COSMOS_INSTALL!\INSTALL.log
@echo WKHTMLPATHWITHPROTOCOL=!WKHTMLPATHWITHPROTOCOL! >> !COSMOS_INSTALL!\INSTALL.log
@echo QTBINDINGS_QT_VERSION=!QTBINDINGS_QT_VERSION! >> !COSMOS_INSTALL!\INSTALL.log
@echo USERDNSDOMAIN=%USERDNSDOMAIN% >> !COSMOS_INSTALL!\INSTALL.log
@echo BALL=!BALL! >> !COSMOS_INSTALL!\INSTALL.log
@echo SSL_CERT_FILE=%SSL_CERT_FILE% >> !COSMOS_INSTALL!\INSTALL.log
@echo ADMIN=!ADMIN! >> !COSMOS_INSTALL!\INSTALL.log
@echo PROCESSOR_ARCHITECTURE=!ARCHITECTURE! >> !COSMOS_INSTALL!\INSTALL.log
@echo. >> !COSMOS_INSTALL!\INSTALL.log

::::::::::::::::::::::::
:: Install Ruby
::::::::::::::::::::::::

if !ARCHITECTURE!==x86 (
  echo Downloading 32-bit Ruby
  powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_32!', '!COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_32!')"
  if errorlevel 1 (
    echo ERROR: Problem downloading 32-bit Ruby from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_32!
    echo INSTALL FAILED
    @echo ERROR: Problem downloading 32-bit Ruby from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_32! >> !COSMOS_INSTALL!\INSTALL.log
    pause
    exit /b 1
  ) else (
    @echo Successfully downloaded 32-bit Ruby from: !PROTOCOL!:!RUBY_INSTALLER_PATH!!RUBY_INSTALLER_32! >> !COSMOS_INSTALL!\INSTALL.log
  )
  echo Installing 32-bit Ruby
  !COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_32! /silent /nomodpath /noassocfiles /dir="!COSMOS_INSTALL!\Vendor\Ruby"
  if errorlevel 1 (
    echo ERROR: Problem installing 32-bit Ruby
    echo INSTALL FAILED
    @echo ERROR: Problem installing 32-bit Ruby >> !COSMOS_INSTALL!\INSTALL.log
    pause
    exit /b 1
  ) else (
    @echo Successfully installed 32-bit Ruby >> !COSMOS_INSTALL!\INSTALL.log
  )
  call !COSMOS_INSTALL!\Vendor\Ruby\bin\ridk install 1 2 3
  call C:\msys64\usr\bin\pacman --noconfirm -S mingw-w64-i686-gettext
) else (
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
  !COSMOS_INSTALL!\tmp\!RUBY_INSTALLER_64! /silent /nomodpath /noassocfiles /dir="!COSMOS_INSTALL!\Vendor\Ruby"
  if errorlevel 1 (
    echo ERROR: Problem installing 64-bit Ruby
    echo INSTALL FAILED
    @echo ERROR: Problem installing 64-bit Ruby >> !COSMOS_INSTALL!\INSTALL.log
    pause
    exit /b 1
  ) else (
    @echo Successfully installed 64-bit Ruby >> !COSMOS_INSTALL!\INSTALL.log
  )
  call !COSMOS_INSTALL!\Vendor\Ruby\bin\ridk install 1 2 3
  call C:\msys64\usr\bin\pacman --noconfirm -S mingw-w64-x86_64-gettext
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

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Download and unzip additional files needed for the installation
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

echo Downloading COSMOS_Windows_Install.zip
powershell -Command "(New-Object Net.WebClient).DownloadFile('!PROTOCOL!:!WINDOWS_INSTALL_ZIP!?raw=true', '!COSMOS_INSTALL!\tmp\COSMOS_Windows_Install.zip')"
if errorlevel 1 (
  echo ERROR: Problem downloading COSMOS Windows files from: !PROTOCOL!:!WINDOWS_INSTALL_ZIP!?raw=true
  echo INSTALL FAILED
  @echo ERROR: Problem downloading COSMOS Windows files from: !PROTOCOL!:!WINDOWS_INSTALL_ZIP!?raw=true >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully downloaded COSMOS Windows files from: !PROTOCOL!:!WINDOWS_INSTALL_ZIP!?raw=true >> !COSMOS_INSTALL!\INSTALL.log
)
SET "UNZIP_TMP=!COSMOS_INSTALL!\tmp\unzip.vbs"
@echo Set ArgObj = WScript.Arguments > !UNZIP_TMP!
@echo strFileZIP = ArgObj(0) >> !UNZIP_TMP!
@echo outFolder = ArgObj(1) ^& "\" >> !UNZIP_TMP!
@echo WScript.Echo ("Extracting file " ^& strFileZIP ^& " to " ^& outFolder) >> !UNZIP_TMP!
@echo Set objShell = CreateObject( "Shell.Application" ) >> !UNZIP_TMP!
@echo Set objSource = objShell.NameSpace(strFileZIP).Items() >> !UNZIP_TMP!
@echo Set objTarget = objShell.NameSpace(outFolder) >> !UNZIP_TMP!
@echo intOptions = 256 >> !UNZIP_TMP!
@echo objTarget.CopyHere objSource, intOptions >> !UNZIP_TMP!
cscript //B !UNZIP_TMP! !COSMOS_INSTALL!\tmp\COSMOS_Windows_Install.zip !COSMOS_INSTALL!
if errorlevel 1 (
  echo ERROR: Problem unzipping COSMOS Windows files
  echo INSTALL FAILED
  @echo ERROR: Problem unzipping COSMOS Windows files >> !COSMOS_INSTALL!\INSTALL.log
  pause
  exit /b 1
) else (
  @echo Successfully unzipped COSMOS Windows files >> !COSMOS_INSTALL!\INSTALL.log
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
SET "GEMRC=!COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\etc\gemrc"
@echo --- > !GEMRC!
@echo :backtrace: false >> !GEMRC!
@echo :benchmark: false >> !GEMRC!
@echo :bulk_threshold: 1000 >> !GEMRC!
@echo :sources: >> !GEMRC!
@echo - !PROTOCOL!://rubygems.org/ >> !GEMRC!
@echo :update_sources: true >> !GEMRC!
@echo :verbose: true >> !GEMRC!

::::::::::::::::::::::::::::
:: Install Gems
::::::::::::::::::::::::::::

:: Set environmental variables
SET "GEM_HOME=!COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\!RUBY_ABI_VERSION!"
SET "GEM_PATH=%GEM_HOME%"

:: Prepend embedded bin to PATH so we prefer those binaries
SET RI_DEVKIT=!COSMOS_INSTALL!\Vendor\Devkit\
SET "PATH=!COSMOS_INSTALL!\Vendor\Ruby\bin;%RI_DEVKIT%bin;%RI_DEVKIT%mingw\bin;%PATH%"

:: Remove RUBYOPT and RUBYLIB, which can cause serious problems.
SET RUBYOPT=
SET RUBYLIB=

call gem install --force rdoc -v 5.1.0

:: install COSMOS gem and dependencies
echo Installing COSMOS gem !COSMOS_VERSION!...
if !COSMOS_VERSION!=="LATEST" (
  call gem install cosmos --no-rdoc --no-ri
) else (
  call gem install cosmos -v !COSMOS_VERSION! --no-rdoc --no-ri
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
if !ARCHITECTURE!==x86 (
  move !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\!RUBY_ABI_VERSION!\gems\qtbindings-qt-!QTBINDINGS_QT_VERSION!-x86-mingw32\qtbin\*.dll !COSMOS_INSTALL!\Vendor\Ruby\bin
) else (
  move !COSMOS_INSTALL!\Vendor\Ruby\lib\ruby\gems\!RUBY_ABI_VERSION!\gems\qtbindings-qt-!QTBINDINGS_QT_VERSION!-x64-mingw32\qtbin\*.dll !COSMOS_INSTALL!\Vendor\Ruby\bin
)
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

:::::::::::::::::::::
:: Perform offline configuration
:::::::::::::::::::::

call !COSMOS_INSTALL!\OFFLINE_CONFIG_COSMOS.bat

ENDLOCAL
