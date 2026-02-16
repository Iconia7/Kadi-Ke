#!/bin/bash
# Kadi Server v13.1 Deployment Script for VPS
# Usage: ./deploy_server_fixed.sh [your-vps-ip] [ssh-user]

VPS_IP=$1
SSH_USER=$2

if [ -z "$VPS_IP" ] || [ -z "$SSH_USER" ]; then
    echo "Usage: ./deploy_server_fixed.sh [vps-ip] [ssh-user]"
    exit 1
fi

# Determine home directory based on user
if [ "$SSH_USER" = "root" ]; then
    HOME_DIR="/root"
else
    HOME_DIR="/home/$SSH_USER"
fi

echo "🚀 Deploying Kadi Server to $SSH_USER@$VPS_IP..."
echo "📁 Home directory: $HOME_DIR"

# 1. Create directory on VPS first
echo "📁 Creating server directory..."
ssh $SSH_USER@$VPS_IP "mkdir -p $HOME_DIR/kadi-server"

# 2. Upload server code
echo "📦 Uploading server files..."
# 2. Upload server code
echo "📦 Uploading server files (preserving database)..."

# Upload bin directory
scp -r ../server/bin $SSH_USER@$VPS_IP:$HOME_DIR/kadi-server/

# Upload pubspec files
scp ../server/pubspec.* $SSH_USER@$VPS_IP:$HOME_DIR/kadi-server/

# Upload analysis_options.yaml if exists
if [ -f "../server/analysis_options.yaml" ]; then
    scp ../server/analysis_options.yaml $SSH_USER@$VPS_IP:$HOME_DIR/kadi-server/
fi

# Upload config.json explicitly
echo "🔒 Uploading security config..."
scp ../server/config.json $SSH_USER@$VPS_IP:$HOME_DIR/kadi-server/

# 3. Install dependencies and setup
echo "⚙️  Setting up server..."
ssh $SSH_USER@$VPS_IP << ENDSSH
    cd $HOME_DIR/kadi-server
    
    # Install Dart and SQLite if not installed
    echo "⚙️  Verifying dependencies..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https wget libsqlite3-dev
    
    # Ensure libsqlite3.so symlink exists (required for Dart sqlite3 package)
    if [ ! -f "/usr/lib/x86_64-linux-gnu/libsqlite3.so" ]; then
        echo "🔗 Creating libsqlite3.so symlink..."
        sudo ln -s /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /usr/lib/x86_64-linux-gnu/libsqlite3.so
    fi

    if ! command -v dart &> /dev/null; then
        echo "🎯 Installing Dart SDK..."
        wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
        echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
        sudo apt-get update
        sudo apt-get install -y dart
    fi
    
    # Get dependencies
    echo "📦 Installing Dart dependencies..."
    dart pub get || { echo "❌ dart pub get failed"; exit 1; }
    
    # Create systemd service
    echo "🔧 Creating systemd service..."
    sudo tee /etc/systemd/system/kadi-server.service > /dev/null <<EOF
[Unit]
Description=Kadi Card Game Server
After=network.target

[Service]
Type=simple
User=$SSH_USER
WorkingDirectory=$HOME_DIR/kadi-server
ExecStart=/usr/lib/dart/bin/dart run bin/server.dart
Restart=always
RestartSec=10
StandardOutput=append:$HOME_DIR/kadi-server/server.log
StandardError=append:$HOME_DIR/kadi-server/server.log

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    echo "🚀 Starting server..."
    sudo systemctl daemon-reload
    sudo systemctl enable kadi-server
    sudo systemctl restart kadi-server
    
    # Open firewall
    echo "🔥 Configuring firewall..."
    sudo ufw allow 8080/tcp 2>/dev/null || true
    
    # Check status
    sleep 3
    echo ""
    echo "📊 Server Status:"
    sudo systemctl status kadi-server --no-pager
    
    echo ""
    echo "📋 Recent logs:"
    tail -20 $HOME_DIR/kadi-server/server.log 2>/dev/null || echo "No logs yet"
    
    echo ""
    echo "🧪 Testing v13.0 Features..."
    sleep 2
    
    # Test health endpoint
    if curl -s http://localhost:8080/health | grep -q "ok"; then
        echo "✅ Server health: OK"
    else
        echo "❌ Server health check failed"
    fi
    
    # Test friend endpoints
    if curl -s "http://localhost:8080/friends/search?username=test" | grep -q "users"; then
        echo "✅ Friend system: Endpoints responding"
    else
        echo "⚠️  Friend system: Check failed"
    fi
    
    echo ""
    echo "📊 Online tracking ready for WebSocket connections"
ENDSSH

echo ""
echo "✅ v13.1 Deployment Complete!"
echo ""
echo "🎉 New Features:"
echo "   • Tutorial System"
echo "   • SQLite Database (kadi_game.db)"
echo "   • Secure Friend System with online status"
echo "   • Enhanced Push Notifications"
echo "   • WebSocket presence tracking"
echo ""
echo "🔍 Monitor server:"
echo "   ssh $SSH_USER@$VPS_IP 'sudo systemctl status kadi-server'"
echo ""
echo "📋 View logs:"
echo "   ssh $SSH_USER@$VPS_IP 'tail -f $HOME_DIR/kadi-server/server.log'"
echo ""
echo "🧪 Test server:"
echo "   curl http://$VPS_IP:8080/health"
echo "   curl http://$VPS_IP:8080/friends/search?username=test"
echo ""
echo "🎮 Update app to use: ws://$VPS_IP:8080"
