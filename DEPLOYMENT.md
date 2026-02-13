# Kadi Ke - Production Deployment Guide

This guide explains how to deploy the **Kadi Ke Game Server** and configure the Flutter Client for production.

## 1. Server Deployment (VPS)

We use a automated shell script to deploy the server to a Linux VPS (Ubuntu/Debian). This handles Dart installation, dependency management, and systemd service setup.

### Prerequisites
- A VPS with SSH access.
- Your project directory available locally.

### Steps
1. **Navigate to scripts**:
   ```powershell
   cd scripts
   ```

2. **Run Deployment**:
   ```powershell
   ./deploy_server_fixed.sh [VPS_IP] [SSH_USER]
   ```
   *Example: `./deploy_server_fixed.sh 5.189.178.132 root`*

3. **Management**:
   - **Status**: `sudo systemctl status kadi-server`
   - **Logs**: `tail -f ~/kadi-server/server.log`
   - **Restart**: `sudo systemctl restart kadi-server`

## 2. Client Configuration

The app uses a centralized configuration system for easy environment switching.

### Configuration File
Modify [app_config.dart](file:///c:/Users/newto/Desktop/card_game_ke/lib/services/app_config.dart) to update the production URL:
```dart
static const String _prodBaseUrl = 'http://你的ip:8080';
static const String _prodWsUrl = 'ws://你的ip:8080';
```

### Build Instructions
To build the production APK/AppBundle:
```bash
flutter build apk --release
# OR
flutter build appbundle --release
```

## 3. Production Features
- **Security**: All passwords are SHA-256 hashed.
- **Matchmaking**: The server automatically manages room discovery.
- **Resilience**: The `kadi-server` service restarts automatically on failure.
- **Live Sync**: Win stats are updated immediately on the global leaderboard.
