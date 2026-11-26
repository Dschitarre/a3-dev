@echo off
rem Mirrors this repo onto the laptop (ssh + scp, no file share needed):
rem   mirrored (files missing here are deleted there): src, scripts, workshop, templates, build\mods, build\mpmissions,
rem     build\missions; the templates' tmp_profiles\culling_profiles (server logs) are kept
rem   copied, nothing deleted: cfg, except the machine-specific files (paths, cullingHC, laptop*)
rem Config (not in git):
rem   cfg\laptopHost.txt  ssh target, e.g. user@laptop
rem   cfg\laptopPath.txt  repo folder on the laptop, without spaces (default C:\a3-dev)
rem Running Arma processes keep working: unchanged files are not touched, changed ones in use fail and are reported.
rem Usage: syncLaptop.bat

setlocal enabledelayedexpansion
if /i "%~1"=="apply" goto apply

call "%~dp0loadCfg.bat"
if not defined laptopHost (
    echo cfg\laptopHost.txt is missing ^(ssh target, e.g. user@laptop^).
    exit /b 1
)
if not defined laptopPath (
    set "laptopPath=C:\a3-dev"
)
set "stage=%laptopPath%\.sync"
set "remoteTar=%laptopPath%\.sync.tar"
set "archive=%TEMP%\a3-dev-sync.tar"

rem ---- pack ----

set "parts=src scripts templates workshop cfg"
for %%d in (build/mods build/mpmissions build/missions) do (
    if exist "%basePath%\%%d" (
        set "parts=!parts! %%d"
    )
)

set "excludes=--exclude=tmp_profiles --exclude=culling_profiles --exclude=__pycache__"
for %%n in (clientProfilePath cullingHC laptopHost laptopPath serverPath steamCmdPath toolsPath workshopModsPath) do (
    set "excludes=!excludes! --exclude=cfg/%%n.txt"
)

echo packing %parts% ...
"%SystemRoot%\System32\tar.exe" -cf "%archive%" -C "%basePath%" %excludes% %parts% || exit /b 1

rem ---- upload and apply ----

echo uploading to %laptopHost% ...
scp -q "%archive%" "%laptopHost%:%remoteTar:\=/%" || exit /b 1
del "%archive%"

echo applying in %laptopPath% ...
ssh %laptopHost% "cmd /c '(if exist %stage% rmdir /s /q %stage%) & mkdir %stage% && tar -xf %remoteTar% -C %stage% && %stage%\scripts\syncLaptop.bat apply %stage% %laptopPath% && rmdir /s /q %stage% && del %remoteTar%'"
if errorlevel 1 (
    echo SYNC FAILED
    exit /b 1
)
echo synced to %laptopHost%:%laptopPath%
exit /b 0

rem ---- laptop side: unpacked archive in <stage> -> <target> ----

:apply
set "stage=%~2"
set "target=%~3"
set "failed="
for %%d in (src scripts workshop build\mods build\mpmissions build\missions) do (
    call :copy "%%d" /MIR
)
call :copy templates /MIR /XD tmp_profiles culling_profiles
call :copy cfg /E
if defined failed (
    exit /b 1
)
exit /b 0

:copy
if not exist "%stage%\%~1" (
    exit /b 0
)
robocopy "%stage%\%~1" "%target%\%~1" %2 %3 %4 %5 /NJH /NJS /NDL /NP /R:2 /W:2
if errorlevel 8 (
    echo failed: %~1
    set "failed=1"
)
exit /b 0
