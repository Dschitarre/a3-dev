@echo off
rem Builds the missions of templates\<template> and/or starts its server.
rem Usage: runTemplate.bat <template> [build|start|buildAndStart]     (default: buildAndStart)

setlocal

set "template=%~1"
set "action=%~2"
if "%action%"=="" (
    set "action=buildAndStart"
)

if "%template%"=="" (
    echo Usage: runTemplate.bat ^<template^> [build^|start^|buildAndStart]
    exit /b 1
)

rem ---- build and start ----

if /i not "%action%"=="start" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Template "%template%" || exit /b 1
)
if /i not "%action%"=="build" (
    call "%~dp0startServer.bat" "%template%"
)

exit /b %errorlevel%
