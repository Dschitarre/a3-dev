@echo off
setlocal enabledelayedexpansion

cd /d %~dp0\..
set basePath=%cd%
cd "%basePath%\src"

for /f "tokens=*" %%g in ('dir gameModes /ad /b') do (
    cd "%basePath%\src\gameModes\%%g\cfg"

    for /f %%m in (maps.txt) do (
        cd "%basePath%\scripts"
        start /b buildMission.bat "%%g" "%%m"
    )
)

exit