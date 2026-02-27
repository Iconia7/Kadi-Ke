@echo off
set SERVER_IP=5.189.178.132
set PORT=8080

:: Extract ADMIN_SECRET_KEY from .env
for /f "tokens=1,2 delims==" %%A in (..\.env) do (
    if "%%A"=="ADMIN_SECRET_KEY" set ADMIN_KEY=%%B
)

if "%ADMIN_KEY%"=="" (
    echo Error: ADMIN_SECRET_KEY not found in ..\.env file!
    pause
    exit /b
)

echo Sending Push Notification to a Specific User...
echo.

set /p USERNAME="Enter exact username to receive push: "
set /p TITLE="Enter Notification Title (e.g., Kadi Tournament): "
set /p BODY="Enter Notification Message: "
set /p IMAGE_URL="Enter Image URL (Leave blank for none): "
set /p ACTION_KEY="Enter Action Button Key (Leave blank for none, e.g. OPEN_CLAN_HUB): "
set /p ACTION_LABEL="Enter Action Button Label (e.g. Enter Clan Hub): "

set JSON_PAYLOAD={\"adminKey\": \"%ADMIN_KEY%\", \"username\": \"%USERNAME%\", \"title\": \"%TITLE%\", \"body\": \"%BODY%\"

if not "%IMAGE_URL%"=="" (
    set JSON_PAYLOAD=%JSON_PAYLOAD%, \"imageUrl\": \"%IMAGE_URL%\"
)

if not "%ACTION_KEY%"=="" (
    set JSON_PAYLOAD=%JSON_PAYLOAD%, \"actions\": [{\"key\": \"%ACTION_KEY%\", \"label\": \"%ACTION_LABEL%\"}]
)

set JSON_PAYLOAD=%JSON_PAYLOAD%}

curl -X POST http://%SERVER_IP%:%PORT%/api/admin/push ^
-H "Content-Type: application/json" ^
-d "%JSON_PAYLOAD%"

echo.
echo.
pause
