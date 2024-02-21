for /f "delims=" %%i in ('cd') do (
    set template=%%~nxi
)

cd /d %~dp0
cd ../../scripts
start /b startServer.bat "%template%"
exit