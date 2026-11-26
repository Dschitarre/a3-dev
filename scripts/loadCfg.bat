@echo off
rem Sets basePath (repo root) and one variable per single-line config file in cfg\.
rem Usage from another script:  call "%~dp0loadCfg.bat"

for %%I in ("%~dp0..") do (
    set "basePath=%%~fI"
)

for %%n in (clientProfilePath cullingHC keyName laptopHost laptopPath serverPath steamCmdPath steamUser toolsPath workshopModsPath) do (
    set "%%n="
    if exist "%basePath%\cfg\%%n.txt" (
        set /p %%n=<"%basePath%\cfg\%%n.txt"
    )
)
exit /b 0
