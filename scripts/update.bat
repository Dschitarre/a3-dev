@echo off
rem Installs/updates via steamcmd (one login for everything):
rem   server  Arma 3 dedicated server (app 233780, creatordlc branch)
rem   tools   Arma 3 Tools (app 233800)
rem   mods    workshop items listed in cfg\mods.txt
rem steamcmd itself is downloaded to cfg\steamCmdPath.txt if it is missing.
rem Usage: update.bat [server] [tools] [mods]     (no argument = all)

setlocal enabledelayedexpansion

call "%~dp0loadCfg.bat"
set "steamCmdExe=%steamCmdPath%\steamcmd.exe"

rem ---- update targets ----

set "targets=%*"
if "%targets%"=="" (
    set "targets=server tools mods"
)

set "commands="
for %%t in (%targets%) do (
    if /i "%%t"=="server" (
        set "commands=!commands! +app_update 233780 -beta creatordlc validate"
    )

    if /i "%%t"=="tools" (
        set "commands=!commands! +app_update 233800 validate"
    )

    if /i "%%t"=="mods" (
        for /f "usebackq tokens=*" %%m in ("%basePath%\cfg\mods.txt") do (
            set "commands=!commands! +workshop_download_item 107410 %%m validate"
        )
    )
)

if not defined commands (
    echo Usage: update.bat [server] [tools] [mods]
    exit /b 1
)

rem ---- SteamCMD installation ----

if not exist "%steamCmdExe%" (
    echo steamcmd not found, installing it to %steamCmdPath% ...
    powershell -NoProfile -Command ^
        "$ErrorActionPreference = 'Stop';" ^
        "$zip = Join-Path $env:TEMP 'steamcmd.zip';" ^
        "Invoke-WebRequest 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zip;" ^
        "Expand-Archive $zip -DestinationPath '%steamCmdPath%' -Force;" ^
        "Remove-Item $zip" || exit /b 1
)

rem ---- run updates ----

"%steamCmdExe%" +login %steamUser% !commands! +quit
exit /b %errorlevel%
