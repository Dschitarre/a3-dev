@echo off
setlocal enabledelayedexpansion

cd /d %~dp0\..
set basePath=%cd%
cd "%basePath%\src"

for /f "tokens=*" %%m in ('dir mods /ad /b') do (
    cd "%basePath%\scripts"
    start /b buildMod.bat "%%m"
)

exit