@echo off
echo Building X4 NVDA Server...
echo.

cd /d "%~dp0"

python -m PyInstaller --clean -y build_exe.spec

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build successful!
    echo.
    echo Copying permissions.json to exe folder...
    copy /y "dist\X4_NVDA_Server\_internal\permissions.json" "dist\X4_NVDA_Server\permissions.json"
    echo Copying X4_Python_Pipe_Server for dynamic module loading...
    xcopy /E /I /Y "X4_Python_Pipe_Server" "dist\X4_NVDA_Server\X4_Python_Pipe_Server"
    echo.
    echo Output: dist\X4_NVDA_Server\
    echo.
    echo Files to distribute:
    dir /b dist\X4_NVDA_Server\
) else (
    echo.
    echo Build failed! Check errors above.
)

echo.
pause
