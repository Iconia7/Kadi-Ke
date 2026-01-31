#!/bin/bash
# Kadi Server Deployment Script for VPS
# 
# Usage: ./deploy_server.sh [your-vps-ip] [ssh-user]
# Example: ./deploy_server.sh 192.168.1.100 root

VPS_IP=$1
SSH_USER=$2

if [ -z "$VPS_IP" ] || [ -z "$SSH_USER" ]; then
    echo "Usage: ./deploy_server.sh [vps-ip] [ssh-user]"
    exit 1
fi

echo "🚀 Deploying Kadi Server to $SSH_USER@$VPS_IP..."

# 1. Upload server code
echo "📦 Uploading server files..."
scp -r ../server $SSH_USER@$VPS_IP:/home/$SSH_USER/kadi-server

# 2. Install dependencies and setup
echo "⚙️  Setting up server..."
ssh $SSH_USER@$VPS_IP << 'ENDSSH'
    cd /home/$SSH_USER/kadi-server
    
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
    dart pub get
    
    # Create systemd service
    sudo tee /etc/systemd/system/kadi-server.service > /dev/null <<EOF
[Unit]
Description=Kadi Card Game Server
After=network.target

[Service]
Type=simple
User=$SSH_USER
WorkingDirectory=/home/$SSH_USER/kadi-server
ExecStart=/usr/lib/dart/bin/dart run bin/server.dart
Restart=always
RestartSec=10
StandardOutput=append:/home/$SSH_USER/kadi-server/server.log
StandardError=append:/home/$SSH_USER/kadi-server/server.log

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    sudo systemctl daemon-reload
    sudo systemctl enable kadi-server
    sudo systemctl restart kadi-server
    
    # Open firewall
    sudo ufw allow 8080/tcp
    
    # Check status
    sleep 2
    sudo systemctl status kadi-server
ENDSSH

echo "✅ Deployment complete!"
echo ""
echo "🔍 Check server status:"
echo "   ssh $SSH_USER@$VPS_IP 'sudo systemctl status kadi-server'"
echo ""
echo "📋 View logs:"
echo "   ssh $SSH_USER@$VPS_IP 'tail -f /home/$SSH_USER/kadi-server/server.log'"
echo ""
echo "🎮 Update app to use: ws://$VPS_IP:8080"
