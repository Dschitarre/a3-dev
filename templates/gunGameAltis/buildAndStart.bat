@echo off
setlocal enabledelayedexpansion

cd /d %~dp0

start /b /wait build.bat
start /b start.bat
exit