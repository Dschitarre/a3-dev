@echo off
rem Builds the missions of templates\<template> and/or starts its server.
rem Usage: runTemplate.bat <template> [build|start|buildAndStart] [true|false]
rem   2nd argument default: buildAndStart
rem   3rd argument: with or without the dedicated culling HC (default: cfg\cullingHC.txt)

setlocal

set "template=%~1"
set "action=%~2"
set "cullingHC=%~3"
if "%action%"=="" (
    set "action=buildAndStart"
)

if "%template%"=="" (
    echo Usage: runTemplate.bat ^<template^> [build^|start^|buildAndStart] [true^|false]
    exit /b 1
)

rem ---- build and start ----

if /i not "%action%"=="start" (
    if defined cullingHC (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Template "%template%" -CullingHC "%cullingHC%" || exit /b 1
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Template "%template%" || exit /b 1
    )
)
if /i not "%action%"=="build" (
    call "%~dp0startServer.bat" "%template%" %cullingHC%
)

exit /b %errorlevel%
