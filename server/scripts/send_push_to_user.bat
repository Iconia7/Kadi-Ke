@echo off
set SERVER_IP=5.189.178.132
set PORT=8080

:: Extract ADMIN_SECRET_KEY from .env
for /f "tokens=1,2 delims==" %%A in (.env) do (
    if "%%A"=="ADMIN_SECRET_KEY" set ADMIN_KEY=%%B
)

if "%ADMIN_KEY%"=="" (
    echo Error: ADMIN_SECRET_KEY not found in .env file!
    pause
    exit /b
)

echo Sending Push Notification to a Specific User...
echo.

set /p USERNAME="Enter exact username to receive push: "
set /p TITLE="Enter Notification Title (e.g., Kadi Tournament): "
set /p BODY="Enter Notification Message: "

curl -X POST http://%SERVER_IP%:%PORT%/api/admin/push ^
-H "Content-Type: application/json" ^
-d "{\"adminKey\": \"%ADMIN_KEY%\", \"username\": \"%USERNAME%\", \"title\": \"%TITLE%\", \"body\": \"%BODY%\"}"

echo.
echo.
pause
