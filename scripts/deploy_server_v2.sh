#!/bin/bash
# Kadi Server v13.2 Deployment Script (Optimized)
# Usage: ./deploy_server_v2.sh [vps-ip] [ssh-user]

VPS_IP=$1
SSH_USER=$2

if [ -z "$VPS_IP" ] || [ -z "$SSH_USER" ]; then
    echo "Usage: ./deploy_server_v2.sh [vps-ip] [ssh-user]"
    exit 1
fi

HOME_DIR=$([ "$SSH_USER" = "root" ] && echo "/root" || echo "/home/$SSH_USER")
LOCAL_SERVER_DIR="../server"
TAR_FILE="kadi_server_deploy.tar.gz"

echo "🚀 Preparing Kadi Server Deployment for $SSH_USER@$VPS_IP..."

# 1. Create a single tarball to avoid multiple SCP connections and timeouts
echo "📦 Creating deployment archive..."
# Exclude database, logs, and any Windows executables
tar -czf $TAR_FILE \
    --exclude='*.db' \
    --exclude='*.log' \
    --exclude='server.exe' \
    --exclude='.dart_tool' \
    --exclude='.git' \
    -C $LOCAL_SERVER_DIR .

if [ $? -ne 0 ]; then
    echo "❌ Failed to create archive."
    exit 1
fi

# 2. Upload the single archive
echo "📤 Uploading archive to VPS..."
scp $TAR_FILE $SSH_USER@$VPS_IP:$HOME_DIR/

if [ $? -ne 0 ]; then
    echo "❌ Upload failed. Check your connection or SSH limits."
    rm $TAR_FILE
    exit 1
fi

# 3. Extract and Setup on VPS
echo "⚙️  Extracting and setting up on VPS..."
ssh $SSH_USER@$VPS_IP << ENDSSH
    mkdir -p $HOME_DIR/kadi-server
    tar -xzf $HOME_DIR/$TAR_FILE -C $HOME_DIR/kadi-server
    rm $HOME_DIR/$TAR_FILE
    
    cd $HOME_DIR/kadi-server
    
    # Verify dependencies
    echo "⚙️  Updating system dependencies..."
    sudo apt-get update -y > /dev/null
    sudo apt-get install -y apt-transport-https wget libsqlite3-dev > /dev/null
    
    # Link SQLite if needed
    if [ ! -f "/usr/lib/x86_64-linux-gnu/libsqlite3.so" ]; then
        sudo ln -s /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /usr/lib/x86_64-linux-gnu/libsqlite3.so 2>/dev/null
    fi

    # Dart SDK check
    if ! command -v dart &> /dev/null; then
        echo "🎯 Installing Dart SDK..."
        wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
        echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
        sudo apt-get update && sudo apt-get install -y dart
    fi
    
    # Get dependencies
    echo "📦 Running dart pub get..."
    dart pub get --offline || dart pub get
    
    # Update systemd service
    echo "🔧 Updating kadi-server.service..."
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
    
    echo "🚀 Restarting Kadi Server..."
    sudo systemctl daemon-reload
    sudo systemctl enable kadi-server
    sudo systemctl restart kadi-server
    
    sleep 2
    echo "📊 Status:"
    sudo systemctl status kadi-server --no-pager | grep "Active:"
    
    echo "🧪 Health Check:"
    curl -s http://localhost:8080/health | grep "status" || echo "❌ Health check failed (Check logs)"
ENDSSH

# Remove local tarball
rm $TAR_FILE
echo ""
echo "✅ Deployment Successful!"
