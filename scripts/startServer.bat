@echo off
rem Starts a dedicated server for templates\<template>:
rem copies the template's mission PBOs and all keys into the server folder, creates a fresh server profile
rem and launches arma3server_x64.exe with the template's server.cfg and mods.
rem   mods.txt          workshop item ids (from cfg\workshopModsPath.txt)
rem   modsOfficial.txt  official mod/DLC folders, e.g. gm
rem   serverMods.txt    own mods from build\mods, loaded server-side only
rem   clientMods.txt    (optional) own mods from build\mods every client needs too, e.g. a map mod built from src\mods;
rem                     each one is loaded only if it is in build\mods (not built = the template runs without it)
rem Usage: startServer.bat <template> [true|false]
rem   2nd argument: start the dedicated culling HC (default: cfg\cullingHC.txt); the mission must contain the HC slot
rem   (build.ps1 -CullingHC true)

setlocal enabledelayedexpansion

set "template=%~1"
if "%template%"=="" (
    echo Usage: startServer.bat ^<template^>
    exit /b 1
)

call "%~dp0loadCfg.bat"
if not "%~2"=="" (
    set "cullingHC=%~2"
)
set "templatePath=%basePath%\templates\%template%"
if not exist "%templatePath%\server.cfg" (
    echo Template "%template%" not found.
    exit /b 1
)

rem ---- template configuration ----

cd /d "%templatePath%"
set /p gameMode=<gameMode.txt
set /p port=<port.txt
set "autoInit="
findstr /i "true" autoInit.txt >nul && set "autoInit=-autoInit"

rem ---- server profile ----

if exist tmp_profiles (
    rmdir /q /s tmp_profiles
)

mkdir tmp_profiles\Users\server
copy /y server.Arma3Profile tmp_profiles\Users\server >nul

rem ---- mod lists and keys ----
rem keys are copied one by one: "copy dir\*.bikey" fails on the Google Drive file system (the PC's repo)

set "mods="
set "serverMods="
for /f "usebackq tokens=*" %%i in ("mods.txt") do (
    for %%k in ("%workshopModsPath%\%%i\keys\*.bikey") do copy /y "%%~fk" "%serverPath%\keys\" >nul
    set "mods=!mods!%workshopModsPath%\%%i;"
)

for /f "usebackq tokens=*" %%i in ("modsOfficial.txt") do (
    set "mods=!mods!%%i;"
)

if exist clientMods.txt (
    for /f "usebackq tokens=*" %%i in ("clientMods.txt") do (
        if exist "%basePath%\build\mods\%%i\addons" (
            for %%k in ("%basePath%\build\mods\%%i\keys\*.bikey" "%basePath%\build\mods\%%i\*.bikey") do copy /y "%%~fk" "%serverPath%\keys\" >nul
            set "mods=!mods!%basePath%\build\mods\%%i;"
        ) else (
            echo client mod %%i is not in build\mods: starting without it
        )
    )
)

for /f "usebackq tokens=*" %%i in ("serverMods.txt") do (
    set "serverMods=!serverMods!%basePath%\build\mods\%%i;"
)

if defined mods set "mods=!mods:~0,-1!"
if defined serverMods set "serverMods=!serverMods:~0,-1!"

rem ---- mission files ----

for /f "usebackq tokens=*" %%i in ("maps.txt") do (
    copy /y "%basePath%\build\mpmissions\%gameMode%.%%i.pbo" "%serverPath%\mpmissions\" >nul
    copy /y "%basePath%\build\mpmissions\%gameMode%.%%i.pbo.%keyName%.bisign" "%serverPath%\mpmissions\" >nul
)
for %%k in ("%basePath%\cfg\keys\*.bikey") do copy /y "%%~fk" "%serverPath%\keys\" >nul

rem ---- launch ----

cd /d "%serverPath%"
start "" arma3server_x64.exe ^
    -world=empty ^
    %autoInit% ^
    -port=%port% ^
    -bepath="%serverPath%\battleye" ^
    -cfg="%basePath%\cfg\basic.cfg" ^
    -config="%templatePath%\server.cfg" ^
    -profiles="%templatePath%\tmp_profiles" ^
    -name=server ^
    -mod="!mods!" ^
    -serverMod="!serverMods!"

rem dedicated culling HC only with cullingHC = true (2nd argument or cfg\cullingHC.txt)
if /i "%cullingHC%"=="true" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0startCullingClient.ps1" -Template "%template%" -Detach
)

exit /b 0
