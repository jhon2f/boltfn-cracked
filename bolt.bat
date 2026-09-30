@echo off
setlocal EnableDelayedExpansion
title boltfn
cd /d "%~dp0"

set LOG=%~dp0bolt.log

python --version >nul 2>&1
if errorlevel 1 ( echo [!] python missing. run install.bat & pause & exit /b 1 )
python -m pip show mitmproxy >nul 2>&1
if errorlevel 1 ( echo [!] mitmproxy missing. run install.bat & pause & exit /b 1 )
if not exist "%~dp0app\libstdc++-6.dll"      ( echo [!] proxy dll missing & pause & exit /b 1 )
if not exist "%~dp0app\libstdc++-6_real.dll" ( echo [!] real dll missing & pause & exit /b 1 )

:MENU
chcp 65001 >nul
color 0F
mode con: cols=110 lines=45
cls
echo.
echo   ┌──────────────────────────────────────────────────────────────┐
echo   │  boltfn  ::  cracked by sassylol  ::  t.me/drobpase          │
echo   └──────────────────────────────────────────────────────────────┘
echo.
echo     tools
echo     ─────
echo       [1]  hotmail checker
echo       [2]  yahoo checker
echo       [3]  netflix vm checker
echo.
echo     info
echo     ────
echo       [4]  how it was cracked
echo       [5]  session log
echo.
echo       [6]  exit
echo.
set /p CHOICE=   boltfn@local:~$ 
set CHOICE=!CHOICE: =!

if "!CHOICE!"=="1" (set TOOL=bolthotmail_patched.exe& set FOLDER=bypass&         goto LAUNCH)
if "!CHOICE!"=="2" (set TOOL=boltyahoo_patched.exe&   set FOLDER=bypass\yahoo&   goto LAUNCH)
if "!CHOICE!"=="3" (set TOOL=boltnetflix_patched.exe& set FOLDER=bypass\netflix& goto LAUNCH)
if "!CHOICE!"=="4" goto CRACKINFO
if "!CHOICE!"=="5" goto SESSIONLOG
if "!CHOICE!"=="6" exit /b
goto MENU

:CRACKINFO
cls
echo.
echo   ┌──────────────────────────────────────────────────────────────┐
echo   │  how boltfn got opened up                                    │
echo   └──────────────────────────────────────────────────────────────┘
echo.
echo   boltfn is a rust binary that talks to a license server at
echo   api.loschichos.lat. on start it reads the machine UUID, posts
echo   it to /auth, gets a JWT back, then pulls an AES-encrypted API
echo   list from /data. the JWT expiry is a few hours. every launch
echo   it does this dance again.
echo.
echo   first thing: the binary was shipping with a pinned CA cert
echo   baked into .rdata. when it opened a TLS connection to the
echo   server, it checked the leaf cert against that pin. any proxy
echo   would get rejected. we found the PEM block, kept its length
echo   the same, and dropped mitmproxy's CA in its place. padded
echo   with newlines to keep the PE sections aligned.
echo.
echo   now mitmproxy could sit in the middle. we let the tool talk
echo   to the real server once, captured both JSON responses
echo   (/auth and /data), and saved them to disk.
echo.
echo   from there it's just replay. a local mitmdump instance reads
echo   those two saved responses and hands them back to any request
echo   hitting api.loschichos.lat. the tool never knows the
echo   difference. no network, no check, no timer.
echo.
echo   the JWT itself we opened up too. base64 decode the middle
echo   segment, you get a plain JSON blob with username, ip, exp,
echo   iat. rewrote username and ip to throwaway values and shoved
echo   expires_in up to a billion seconds. re-encoded the exact
echo   same structure so the signature stays valid.
echo.
echo   result: three tools, permanent offline license, no server
echo   calls, no expiration.
echo.
echo   ────────────────────────────────────────────────────────────
echo      cracked by sassylol  -  t.me/drobpase
echo   ────────────────────────────────────────────────────────────
echo.
pause
goto MENU

:SESSIONLOG
cls
echo.
echo   ┌──────────────────────────────────────────────────────────────┐
echo   │  session log                                                 │
echo   └──────────────────────────────────────────────────────────────┘
echo.
if not exist "%LOG%" ( echo   no entries yet. & pause & goto MENU )
type "%LOG%"
echo.
pause
goto MENU

:LAUNCH
set TS=%date% %time%
echo [%TS%] launch: !TOOL! >> "%LOG%"

REM ---- force-sync user data root -> app\, every launch ----
set ROOT=%~dp0
set APPDIR=%~dp0app

if not exist "%APPDIR%\" mkdir "%APPDIR%" >nul 2>&1

call :ENSURE_FILE "proxies.txt"
call :ENSURE_FILE "apis.txt"
call :ENSURE_FILE "config.yml"
call :ENSURE_DIR  "combos"
call :ENSURE_DIR  "result"
REM ---------------------------------------------------------

taskkill /F /IM mitmdump.exe /T >nul 2>&1
taskkill /F /IM mitmproxy.exe /T >nul 2>&1
echo [%TS%] old proxies killed >> "%LOG%"

set PORT=8080
set FOUND=0
for /L %%P in (8080,1,8090) do (
    if !FOUND!==0 (
        netstat -ano 2>nul | findstr :%%P | findstr LISTENING >nul
        if errorlevel 1 (
            set PORT=%%P
            set FOUND=1
        )
    )
)
if !FOUND!==0 ( cls & echo   [!] no free port 8080-8090 & pause & goto MENU )
echo [%TS%] using port !PORT! >> "%LOG%"

if not exist "%~dp0!FOLDER!\replay.py" (
    cls
    echo   [!] missing !FOLDER!\replay.py
    pause
    goto MENU
)

pushd "%~dp0"
start "" /B cmd /c "mitmdump --listen-port !PORT! --allow-hosts api.loschichos.lat --set connection_strategy=lazy --set upstream_cert=false -s ""!FOLDER!\replay.py"" >> ""app\mitm.log"" 2>&1"
popd
echo [%TS%] mitmdump started on !PORT! >> "%LOG%"

set MITM_OK=0
for /L %%i in (1,1,10) do (
    if !MITM_OK!==0 (
        timeout /t 1 /nobreak >nul
        netstat -ano 2>nul | findstr :!PORT! | findstr LISTENING >nul
        if !errorlevel!==0 set MITM_OK=1
    )
)
if !MITM_OK!==0 ( cls & echo   [!] mitmdump failed on !PORT! & pause & goto MENU )
echo [%TS%] proxy listening >> "%LOG%"

set HTTP_PROXY=http://127.0.0.1:!PORT!
set HTTPS_PROXY=http://127.0.0.1:!PORT!

REM reset console state for the tool
chcp 437 >nul
color 07
mode con: cols=120 lines=40
cls
echo [%TS%] launching !TOOL! >> "%LOG%"

REM launch with CWD = app\ (original behavior)
pushd "%~dp0app"
"!TOOL!"
set RC=!errorlevel!
popd
echo [%TS%] tool exit !RC! >> "%LOG%"

taskkill /F /IM mitmdump.exe /T >nul 2>&1
echo [%TS%] proxy killed >> "%LOG%"
cls
goto MENU

REM ============================================================
REM helpers  (pure copy, no mklink, no junction - works anywhere)
REM ============================================================

:ENSURE_FILE
REM %~1 = filename relative to root
if not exist "%ROOT%%~1" (
    echo [%TS%] WARN: %~1 not found in root >> "%LOG%"
    goto :eof
)
copy /Y "%ROOT%%~1" "%APPDIR%\%~1" >nul 2>&1
if errorlevel 1 (
    echo [%TS%] FAIL copy %~1 >> "%LOG%"
) else (
    echo [%TS%] copied %~1 -^> app\ >> "%LOG%"
)
goto :eof

:ENSURE_DIR
REM %~1 = dirname relative to root
if not exist "%ROOT%%~1\" goto :eof
if not exist "%APPDIR%\%~1\" mkdir "%APPDIR%\%~1" >nul 2>&1
xcopy /E /I /Y /Q "%ROOT%%~1\*" "%APPDIR%\%~1\" >nul 2>&1
echo [%TS%] synced %~1\ -^> app\ >> "%LOG%"
goto :eof