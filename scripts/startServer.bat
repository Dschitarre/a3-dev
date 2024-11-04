@echo off
setlocal enabledelayedexpansion

set template=%~1
if "%template%"=="" exit
cd /d %~dp0\..
set basePath=%cd%
set serverConfigPath="%basePath%\templates\%template%"
set workshopBasePath=C:\Program Files (x86)\Steam\steamapps\workshop\content\107410
cd "%basePath%\cfg"
set /p serverPath=<serverPath.txt
set /p keyName=<keyName.txt
cd /d %serverConfigPath%
set /p gameMode=<gameMode.txt
rmdir /q /s tmp_profiles
mkdir tmp_profiles
mkdir tmp_profiles\Users
mkdir tmp_profiles\Users\server
copy /y server.Arma3Profile tmp_profiles\Users\server
set /p gameMode=<gameMode.txt
set /p port=<port.txt
set mods=
set serverMods=
for /f "usebackq tokens=*" %%i in (serverMods.txt) do call :concatServerMods "%%i"
for /f "usebackq tokens=*" %%i in (mods.txt) do call :concatMods "%%i"
for /f "usebackq tokens=*" %%i in (modsOfficial.txt) do call :concatModsOfficial "%%i"
set serverMods=%serverMods:~0,-1%
set mods=%mods:~0,-1%
set autoInit=
find /c "true" autoInit.txt
if %errorlevel% equ 1 goto skip
set autoInit=-autoInit
:skip

for /f %%i in (maps.txt) do (
    set missionPbo="%basePath%\build\mpmissions\%gameMode%.%%i.pbo"
    set missionPboServer="%serverPath%\mpmissions\%gameMode%.%%i.pbo"
    copy /y !missionPbo! !missionPboServer!
    copy /y !missionPbo!.%keyName%.bisign !missionPboServer!.%keyName%.bisign
)

for %%i in (dir /b "%basePath%\cfg\keys\*.bikey") do (
    copy "%%i" "%serverPath%\keys\" /y
)

cd /d "%serverPath%"
start arma3server_x64.exe ^
    -world=empty ^
    %autoInit% ^
    -port=%port% ^
    -bepath="%serverPath%\battleye" ^
    -cfg="%basePath%\cfg\basic.cfg" ^
    -config=%serverConfigPath%\server.cfg ^
    -profiles=%serverConfigPath%\tmp_profiles ^
    -name=server ^
    -mod="%mods%" ^
    -serverMod="%serverMods%"
goto :end

:concatMods
set mods=%mods%%workshopBasePath%\%~1;
goto :eof

:concatServerMods
set serverMods=%serverMods%%basePath%\build\mods\%~1;
goto :eof

:concatModsOfficial
set mods=%mods%%~1;
goto :eof

:end
exit