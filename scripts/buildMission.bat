@echo off
setlocal enabledelayedexpansion

set gameMode=%~1
set map=%~2
cd /d %~dp0\..
set basePath=%cd%
cd "%basePath%\cfg"
set /p toolsPath=<toolsPath.txt
set /p clientProfilePath=<clientProfilePath.txt
set /p keyName=<keyName.txt
set gameModePath=%basePath%\src\gameModes\%gameMode%
cd "%gameModePath%\cfg"
set /p gameModeTag=<gameModeTag.txt

find /c "true" isMultiplayer.txt
if !errorlevel! equ 1 (
    set missionFolder=missions
) else (
    set missionFolder=mpmissions
)

set missionPath=%basePath%\build\!missionFolder!\%gameMode%.%map%
del /q /s "!missionPath!.pbo"
del /q /s "!missionPath!.pbo.%keyName%.bisign"
rmdir /q /s "!missionPath!"
xcopy /h /i /c /k /e /r /y "%gameModePath%" "!missionPath!"
del /q /s "!missionPath!\%gameModeTag%\maps\mapData*.hpp"
del /q /s "!missionPath!\%gameModeTag%\maps\mapName*.hpp"
rmdir /q /s "!missionPath!\missionFiles"
copy /y "%gameModePath%\%gameModeTag%\maps\mapData%map%.hpp" ^
    "!missionPath!\%gameModeTag%\maps\mapData.hpp"
copy /y "%gameModePath%\%gameModeTag%\maps\mapName%map%.hpp" ^
    "!missionPath!\%gameModeTag%\maps\mapName.hpp"
copy /y "%gameModePath%\missionFiles\mission%map%.sqm" "!missionPath!\mission.sqm"
mkdir "!missionPath!\modsIntegrated"

for /f %%m in (modsIntegrated.txt) do (
    xcopy /h /i /c /k /e /r /y ^
        "%basePath%\src\mods\%%m\addons\%%m\scripts" ^
        "!missionPath!\modsIntegrated\%%m\scripts"
    del /q /s "!missionPath!\modsIntegrated\%%m\scripts\fn_init.sqf"
)

rmdir /q /s "!missionPath!\cfg"
rmdir /q /s "%clientProfilePath%\!missionFolder!\%gameMode%.%map%"
xcopy /h /i /c /k /e /r /y "!missionPath!" ^
    "%clientProfilePath%\!missionFolder!\%gameMode%.%map%"

"%toolsPath%\AddonBuilder\AddonBuilder.exe" ^
    "!missionPath!" ^
    "%basePath%\build\!missionFolder!" ^
    -include="%basePath%\cfg\include.lst" ^
    -sign="%basePath%\cfg\keys\%keyName%.biprivatekey" ^
    -clear

rmdir /q /s "!missionPath!"
"%basePath%\scripts\rclone.exe" copy "!missionPath!.pbo" gdrive:a3-dev\build\!missionFolder!
"%basePath%\scripts\rclone.exe" copy "!missionPath!.pbo.%keyName%.bisign" gdrive:a3-dev\build\!missionFolder!

exit