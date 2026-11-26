@echo off
rem Builds this template's missions and starts its server without the dedicated culling HC.
for %%I in ("%~dp0.") do set "template=%%~nxI"
call "%~dp0..\..\scripts\runTemplate.bat" "%template%" buildAndStart false
if errorlevel 1 pause
