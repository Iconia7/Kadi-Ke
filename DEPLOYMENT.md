# Kadi Ke - Deployment Guide

This guide explains how to deploy the **Kadi Ke Game Server** to a production environment (VPS) and how to configure the Flutter Client to connect to it.

## 1. Server Deployment (Docker)

The easiest way to run the server is using Docker Compose. This ensures the server restarts automatically if it crashes or the VPS reboots.

### Prerequisites
- A VPS (Virtual Private Server) running Ubuntu/Debian (e.g., DigitalOcean, AWS, Render).
- Docker and Docker Compose installed.

### Steps
1. **Copy Files**: Upload the `server` directory and `docker-compose.yml` to your VPS.
   ```bash
   scp -r server/ user@your-vps-ip:~/kadi-server
   scp docker-compose.yml user@your-vps-ip:~/kadi-server
   ```

2. **Run Server**:
   Navigate to the directory and start the container.
   ```bash
   cd ~/kadi-server
   docker-compose up -d --build
   ```

3. **Verify**:
   Check if the server is running:
   ```bash
   docker ps
   # You should see 'kadi-server' running on port 8080.
   ```
   
   View logs:
   ```bash
   docker logs -f kadi-server
   ```

4. **Health Check**:
   The server exposes a health endpoint at `/health`. You can allow Uptime monitoring services to ping this URL.
   ```
   GET http://your-vps-ip:8080/health
   ```

## 2. Client Configuration

The Flutter client defaults to the production URL, but this can be changed dynamically.

### Standard Setup
By default, the app connects to: `wss://kadi-ke.onrender.com`.
To change this for a custom build, modify `lib/services/online_game_service.dart`:
```dart
final String _serverUrl = "wss://your-vps-domain.com"; 
```

### Dynamic Configuration (In-App)
Users can change the server URL without rebuilding the app:
1. Open the App.
2. Go to **Settings**.
3. Scroll to **NETWORK (Advanced)**.
4. Enter your WebSocket URL (e.g., `ws://192.168.1.50:8080` or `wss://my-game.com`).
5. Press Enter/Done.
6. **Restart the App** for the change to take full effect.

## 3. Maintenance

- **Update Server**:
  ```bash
  git pull
  docker-compose up -d --build
  ```
- **Restart Server**:
  ```bash
  docker-compose restart
  ```
