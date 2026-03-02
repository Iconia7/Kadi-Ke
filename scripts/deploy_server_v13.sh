#!/bin/bash
# Kadi Server v13.2 Robust Deployment Script
# This script uses a single tarball and a single SSH connection to avoid timeouts and password prompts.

VPS_IP=$1
SSH_USER=$2

if [ -z "$VPS_IP" ] || [ -z "$SSH_USER" ]; then
    echo "Usage: ./deploy_server_v13.sh [vps-ip] [ssh-user]"
    exit 1
fi

HOME_DIR=$([ "$SSH_USER" = "root" ] && echo "/root" || echo "/home/$SSH_USER")
LOCAL_DIR="../server"
TAR_FILE="kadi_deploy.tar.gz"

echo "🚀 Starting Robust Deployment to $SSH_USER@$VPS_IP..."

# 1. Create Deployment Archive
echo "📦 Creating archive (excluding database/logs/temp)..."
tar -czf $TAR_FILE \
    --exclude='*.db' \
    --exclude='*.log' \
    --exclude='server.exe' \
    --exclude='.dart_tool' \
    --exclude='.git' \
    --exclude='bin/uploads/avatars/*' \
    -C $LOCAL_DIR .

if [ $? -ne 0 ]; then
    echo "❌ Failed to create archive."
    exit 1
fi

# 2. Upload with a single SCP command
echo "📤 Uploading archive..."
scp $TAR_FILE $SSH_USER@$VPS_IP:$HOME_DIR/

if [ $? -ne 0 ]; then
    echo "❌ Upload failed. SSH connection issues detected."
    rm $TAR_FILE
    exit 1
fi

# 3. Setup and Restart on VPS via single SSH connection
echo "⚙️  Setting up and Restarting Server on VPS..."
ssh $SSH_USER@$VPS_IP << ENDSSH
    set -e
    mkdir -p $HOME_DIR/kadi-server
    
    echo "📂 Extracting files..."
    tar -xzf $HOME_DIR/$TAR_FILE -C $HOME_DIR/kadi-server
    rm $HOME_DIR/$TAR_FILE
    
    cd $HOME_DIR/kadi-server

    echo "⚙️  Verifying dependencies..."
    # Faster check for essentials
    if ! command -v dart &> /dev/null || [ ! -f "/usr/lib/x86_64-linux-gnu/libsqlite3.so" ]; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq dart libsqlite3-dev
        # Link SQLite if needed
        if [ ! -f "/usr/lib/x86_64-linux-gnu/libsqlite3.so" ]; then
            sudo ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /usr/lib/x86_64-linux-gnu/libsqlite3.so
        fi
    fi

    echo "📦 Updating Dart packages..."
    dart pub get --offline || dart pub get

    echo "🔧 Refreshing systemd service..."
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
RestartSec=5
StandardOutput=append:$HOME_DIR/kadi-server/server.log
StandardError=append:$HOME_DIR/kadi-server/server.log

[Install]
WantedBy=multi-user.target
EOF

    echo "🚀 Restarting server..."
    sudo systemctl daemon-reload
    sudo systemctl restart kadi-server
    
    echo "📊 Service Status:"
    sudo systemctl is-active kadi-server || echo "❌ Service failed to start!"
    
    echo "🧪 Health Check:"
    sleep 3
    curl -s http://localhost:8080/health | grep "status" || echo "❌ Health check failed (Check server.log)"
ENDSSH

# Cleanup
rm $TAR_FILE
echo ""
echo "✅ Deployment Complete! Server is being restarted."
echo "💡 To view logs: ssh $SSH_USER@$VPS_IP 'tail -f $HOME_DIR/kadi-server/server.log'"
