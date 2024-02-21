@echo off
setlocal enabledelayedexpansion

cd /d %~dp0
start /b buildAllMods.bat
start /b buildAllMissions.bat

exit