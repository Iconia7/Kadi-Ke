@echo off
set SERVER_IP=5.189.178.132

echo ==============================================
echo   FCM Push Notification Image Uploader (SCP)
echo ==============================================
echo.

set /p LOCAL_FILE="Enter the full path to your local image (e.g., C:\Users\Downloads\banner.png): "
if not exist "%LOCAL_FILE%" (
    echo Error: File does not exist!
    pause
    exit /b
)

:: Get filename from path
for %%F in ("%LOCAL_FILE%") do set FILENAME=%%~nxF

set SSH_USER=root
set /p USER_INPUT="Enter VPS SSH User (Press Enter for 'root'): "
if not "%USER_INPUT%"=="" set SSH_USER=%USER_INPUT%

if "%SSH_USER%"=="root" (
    set REMOTE_PATH=/root/kadi-server/bin/uploads/%FILENAME%
) else (
    set REMOTE_PATH=/home/%SSH_USER%/kadi-server/bin/uploads/%FILENAME%
)

echo.
echo Uploading "%FILENAME%" to the VPS server...
scp "%LOCAL_FILE%" %SSH_USER%@%SERVER_IP%:%REMOTE_PATH%

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Upload Successful!
    echo.
    echo When sending a push notification, copy and paste this exact URL:
    echo http://%SERVER_IP%:8080/uploads/%FILENAME%
    echo.
) else (
    echo.
    echo ❌ Upload Failed. Check your SSH connection or file permissions.
    echo.
)

pause
