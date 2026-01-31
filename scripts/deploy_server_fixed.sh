#!/bin/bash
# Fixed Kadi Server Deployment Script for VPS
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
scp -r ../server/* $SSH_USER@$VPS_IP:$HOME_DIR/kadi-server/

# 3. Install dependencies and setup
echo "⚙️  Setting up server..."
ssh $SSH_USER@$VPS_IP << ENDSSH
    cd $HOME_DIR/kadi-server
    
    # Install Dart if not installed
    if ! command -v dart &> /dev/null; then
        echo "Installing Dart..."
        sudo apt-get update
        sudo apt-get install -y apt-transport-https wget
        wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
        echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
        sudo apt-get update
        sudo apt-get install -y dart
    fi
    
    # Get dependencies
    echo "📦 Installing Dart dependencies..."
    dart pub get
    
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
ENDSSH

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔍 Check server status:"
echo "   ssh $SSH_USER@$VPS_IP 'sudo systemctl status kadi-server'"
echo ""
echo "📋 View logs:"
echo "   ssh $SSH_USER@$VPS_IP 'tail -f $HOME_DIR/kadi-server/server.log'"
echo ""
echo "🎮 Update app to use: ws://$VPS_IP:8080"
