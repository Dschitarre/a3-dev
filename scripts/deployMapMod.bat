@echo off
rem Copies an externally built map mod (e.g. a terrain build) into build\mods\<name> and signs its PBOs with the repo
rem key, so templates can load it through clientMods.txt (server -mod; clients need the same mod).
rem Usage: deployMapMod.bat <source mod folder> <name>
rem   e.g. deployMapMod.bat C:\a3-localtest\tmp\dayz_surface\chernarus_dayz\@BR_Chernarus_DayZ_v10 @Chernarus2020BaseExpansion

setlocal

set "source=%~f1"
set "name=%~2"
if "%name%"=="" (
    echo Usage: deployMapMod.bat ^<source mod folder^> ^<name^>
    exit /b 1
)
if not exist "%source%\addons\*.pbo" (
    echo no addons\*.pbo in %source%
    exit /b 1
)

call "%~dp0loadCfg.bat"
set "target=%basePath%\build\mods\%name%"
set "privateKey=%basePath%\cfg\keys\%keyName%.biprivatekey"

rem ---- copy ----

if exist "%target%" (
    rmdir /s /q "%target%"
)
mkdir "%target%\addons" "%target%\keys"
copy /y "%source%\addons\*.pbo" "%target%\addons\" >nul || exit /b 1
if exist "%source%\mod.cpp" (
    copy /y "%source%\mod.cpp" "%target%\" >nul
)
copy /y "%basePath%\cfg\keys\%keyName%.bikey" "%target%\keys\" >nul || exit /b 1

rem ---- sign ----

for %%p in ("%target%\addons\*.pbo") do (
    "%toolsPath%\DSSignFile\DSSignFile.exe" "%privateKey%" "%%~fp"
    if not exist "%%~fp.%keyName%.bisign" (
        echo signing failed: %%~nxp
        exit /b 1
    )
)

echo %source%> "%target%\source.txt"
echo deployed %source% -^> %target% ^(signed with %keyName%^)
exit /b 0
