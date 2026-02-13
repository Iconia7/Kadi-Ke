#!/bin/bash
# Kadi Server v13.0 Deployment Script for VPS
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
    
    # Migrate database for v13.0
    echo "🔄 Running v13.0 database migration..."
    cat > migrate_v13.dart <<'MIGRATE'
import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('users.json');
  if (!file.existsSync()) {
    print('⚠️  users.json not found - skipping migration');
    return;
  }
  
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  
  bool changed = false;
  data.forEach((username, userData) {
    // Add friends field if missing
    if (userData['friends'] == null) {
      userData['friends'] = [];
      changed = true;
      print('✅ Added friends field to $username');
    }
  });
  
  if (changed) {
    // Backup before writing
    final backup = File('users.json.backup');
    backup.writeAsStringSync(file.readAsStringSync());
    
    file.writeAsStringSync(jsonEncode(data));
    print('✅ Migration complete! Backup saved to users.json.backup');
  } else {
    print('✅ No migration needed - schema already up to date');
  }
}
MIGRATE
    
    dart run migrate_v13.dart
    rm migrate_v13.dart
    
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
echo "✅ v13.0 Deployment Complete!"
echo ""
echo "🎉 New Features:"
echo "   • Tutorial System"
echo "   • Friend System with online status"
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
