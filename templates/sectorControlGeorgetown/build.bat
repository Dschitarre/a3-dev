@echo off
setlocal enabledelayedexpansion

cd /d %~dp0
set basePath=%cd%/../..
set /p gameMode=<gameMode.txt

for /f %%m in (maps.txt) do (
    cd "%basePath%\scripts"
    start /b /wait buildMission.bat "%gameMode%" "%%m"
)

exit