@echo off
setlocal EnableDelayedExpansion
title BoltFN Setup
cd /d "%~dp0"
set ROOT=%~dp0
set APP=%ROOT%app

REM Admin check
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo   Administrator required for cert + Defender setup.
    echo   Right-click install.bat - Run as administrator.
    echo.
    pause
    exit /b 1
)

echo.
echo   BoltFN Setup
echo   ------------
echo.

REM 1. Python
python --version >nul 2>&1
if errorlevel 1 (
    echo   Installing Python 3.11...
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile '%TEMP%\py.exe' -UseBasicParsing" >nul 2>&1
    if not exist "%TEMP%\py.exe" ( echo   Download failed. & pause & exit /b 1 )
    "%TEMP%\py.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_pip=1
    del "%TEMP%\py.exe" 2>nul
    set "PATH=%PATH%;C:\Program Files\Python311;C:\Program Files\Python311\Scripts"
    timeout /t 3 >nul
    python --version >nul 2>&1
    if errorlevel 1 ( echo   Python installed. Re-run install.bat. & pause & exit /b 0 )
)

REM 2. pip
python -m pip --version >nul 2>&1
if errorlevel 1 python -m ensurepip --upgrade >nul 2>&1

REM 3. mitmproxy
python -m pip show mitmproxy >nul 2>&1
if errorlevel 1 (
    echo   Installing mitmproxy...
    python -m pip install --upgrade pip >nul 2>&1
    python -m pip install mitmproxy >nul 2>&1
)

REM 4. cert
if not exist "%USERPROFILE%\.mitmproxy\mitmproxy-ca-cert.pem" (
    echo   Generating certificate...
    start "" /MIN cmd /c "mitmproxy --listen-port 9999 & timeout /t 5 >nul & taskkill /F /IM mitmproxy.exe >nul 2>&1"
    timeout /t 8 >nul
)
if exist "%USERPROFILE%\.mitmproxy\mitmproxy-ca-cert.pem" (
    certutil -addstore -f Root "%USERPROFILE%\.mitmproxy\mitmproxy-ca-cert.pem" >nul 2>&1
)

REM 5. Defender
powershell -Command "Add-MpPreference -ExclusionPath '%ROOT%' -ErrorAction SilentlyContinue" >nul 2>&1

REM 6. Files
set FAIL=0
for %%F in (
    "app\bolthotmail_patched.exe"
    "app\boltyahoo_patched.exe"
    "app\boltnetflix_patched.exe"
    "app\libstdc++-6.dll"
    "app\libstdc++-6_real.dll"
    "app\libgcc_s_seh-1.dll"
    "app\libwinpthread-1.dll"
    "bypass\replay.py"
    "bypass\auth.json"
    "bypass\data.json"
    "bypass\yahoo\replay.py"
    "bypass\yahoo\auth.json"
    "bypass\yahoo\data.json"
    "bypass\netflix\replay.py"
    "bypass\netflix\auth.json"
    "bypass\netflix\data.json"
) do if not exist "%%~F" ( echo   MISSING: %%F & set FAIL=1 )

if !FAIL!==1 (
    echo.
    echo   Setup failed - files missing.
    pause
    exit /b 1
)

echo.
echo   Setup complete. Launching...
echo.
timeout /t 2 >nul
call "%ROOT%bolt.bat"