# Kadi KE 🃏

**Kadi KE** is a premium, cross-platform digital card game built with **Flutter**.  
It brings the popular Kenyan **Kadi** and **Go Fish** card games to your mobile device with a sleek **"Midnight Elite"** aesthetic and robust multiplayer capabilities.

---

## 🎉 What's New in v13.0

### 🎓 Interactive Tutorial System
- Step-by-step guided tour for new players
- Learn Kadi rules, power cards, and game mechanics
- Replay anytime from Settings
- Beautiful visual demonstrations

### 👥 Friend System
- **Add Friends** - Search and connect with other players
- **Friend Requests** - Send, accept, or decline invitations
- **Online Status** - See who's online with real-time indicators
- **Game Invites** - Challenge friends directly from their profile
- **Friend Achievements** - Unlock social milestones

### 🔔 Enhanced Push Notifications
- **Smart Notifications** - Friend online, game invites, tournaments
- **Granular Control** - Toggle each notification type individually
- **Deep Linking** - Tap notifications to jump directly to relevant screens
- **Notification Channels** - Social, Events, and Progress categories
- **Test Mode** - Try all notification types from Settings

---

## 🚀 Features

### 🎮 Three Distinct Game Modes
- **Offline Single Player**  
  Challenge smart AI bots without needing an internet connection.

- **Online Multiplayer**  
  Play with friends anywhere in the world using private **Room Codes** and WebSocket connections.

- **Local LAN Party**  
  Host lag-free games on your local Wi-Fi network for the ultimate party experience.

---

### 🎨 "Midnight Elite" UI
- **Glassmorphism**  
  A modern, dark-themed interface with transparent elements and neon accents.

- **Dynamic Animations**  
  Smooth card throwing physics, victory confetti, and interactive turn indicators.

- **Responsive Design**  
  Smart hand layout logic ensures cards never get cut off, regardless of hand size.

---

### 🛠 Advanced Mechanics
- **Auto-Reshuffling**  
  The discard pile recycles automatically when the deck runs dry.

- **Multi-Deck Support**  
  Intelligently scales the number of decks based on player count (up to 3 decks).

- **Live Chat**  
  Integrated in-game chat for Online and LAN modes.

- **Progression System**  
  Earn coins, track win rates, and unlock custom **Card Skins** and **Table Themes** in the Shop.

- **Daily Challenges**  
  Complete objectives for bonus rewards and streak bonuses.

- **Achievements**  
  Unlock milestones including friend-based achievements.

---

## 📜 Game Rules (Kadi)

### Objective
Be the first player to finish all your cards.

### Core Rules
- **Matching**  
  Play a card that matches the **Suit** or **Rank** of the top card.

- **Power Cards (Bombs)**  
  `2`, `3`, and `Joker` increase the picking penalty. They can be played at any time.

### Defending Against Bombs
- **Stack** – Play another bomb to pass the penalty forward  
- **King** – Return the penalty to the sender  
- **Jack** – Skip the next player  
- **Ace** – Block the bomb completely (resets penalty to 0)

### Question Cards
- **Queen (Q) & 8**  
  When played, the same player must immediately play an **Answer card**  
  (a non-power card of the same suit).

### Niko Kadi Rule
You **MUST** press the **"Niko Kadi"** warning button if you are left with:
- One card, or
- Multiple cards of the same rank  

Failure to do so results in a **+2 card penalty**.

### Cardless State
If you finish with a **Power Card**, you are **Cardless (0 cards)** but **haven't won yet**.  
You must pick on your next turn.

---

## 🛠 Tech Stack

- **Framework:** Flutter (Dart)
- **Backend:**  
  - Custom Dart Server (WebSocket + REST API)
  - VPS deployment with systemd

- **Networking:**  
  - `web_socket_channel`  
  - `shelf` server framework
  - Real-time presence tracking

- **State Management:**  
  - `setState`  
  - `StreamController` patterns

- **Persistence:**  
  - `shared_preferences` (Local stats & unlocks)
  - JSON-based user database

- **Notifications:**
  - `awesome_notifications` (Local push notifications)

---

## 📦 Installation

### Clone the repository
```bash
git clone https://github.com/Iconia7/Kadi-Ke.git
cd Kadi-Ke
```

### Install dependencies
```bash
flutter pub get
cd server
dart pub get
```

### Run the server (Optional - for online multiplayer)
```bash
cd server
dart run bin/server.dart
```

### Run the app
```bash
flutter run
```

---

## 🚀 Deployment

### Deploy Server to VPS
```bash
cd scripts
./deploy_server_fixed.sh YOUR_VPS_IP YOUR_SSH_USER
```

The script will:
- ✅ Upload server code
- ✅ Install Dart dependencies
- ✅ Run database migrations
- ✅ Set up systemd service
- ✅ Verify endpoints

### Build App for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires macOS)
flutter build ios --release
```

### Shorebird OTA Updates (Recommended)
Shorebird allows you to push Dart code changes directly to users' devices instantly without going through the Play Store review process.

**1. Create a New Release (Play Store Upload)**
Run this to build your aab file that you should upload to the Play Store console:
```bash
shorebird release android
```

**2. Push an Instant Patch (OTA Bug Fix)**
Made a quick bug fix? Run this to push the update instantly to all users on the current release:
```bash
shorebird patch android
```
*Note: Shorebird patches only apply to Dart code. If you add new native dependencies or assets, you must create a new Release.*

---

## 📱 Server Configuration

Update the server URL in your app:
1. Open `lib/services/vps_game_service.dart`
2. Set `_serverUrl` to your VPS address:
   ```dart
   final String _serverUrl = 'ws://YOUR_VPS_IP:8080';
   ```

---

## 🎮 How to Play

1. **First Launch** - Complete the tutorial to learn the basics
2. **Add Friends** - Tap the friends icon and search for players
3. **Create Game** - Choose game mode, set entry fee (optional)
4. **Invite Friends** - Share room code or send direct invites
5. **Play & Win** - Follow the rules and be the first to finish!

---

## 🤝 Contributing

Contributions are welcome!

### Fork the project

### Create your feature branch
```bash
git checkout -b feature/AmazingFeature
```

### Commit your changes
```bash
git commit -m "Add some AmazingFeature"
```

### Push to the branch
```bash
git push origin feature/AmazingFeature
```

### Open a Pull Request

---

## 🐛 Troubleshooting

**Server won't start:**
```bash
ssh user@vps "tail -50 /root/kadi-server/server.log"
```

**Friend system not working:**
- Verify server has WebSocket support
- Check users have sent JOIN action on connect

**Notifications not appearing:**
- Enable notification permissions in device settings
- Check preferences in app Settings → Notification Preferences

---

## 📄 License

Distributed under the MIT License.  
See LICENSE for more information.

---

## 🏆 Version History

- **v13.0** (2026-02-12) - Tutorial System, Friend System, Enhanced Notifications
- **v12.0** - Progression System, Daily Challenges, Achievements
- **v11.0** - Shop System, Card Skins, Table Themes

---

### Made with ❤️ by Nexora Creative Solutions.