# Kadi KE 🃏

**Kadi KE** is a premium, cross-platform digital card game built with **Flutter**.  
It brings the popular Kenyan **Kadi** and **Go Fish** card games to your mobile device with a sleek **“Midnight Elite”** aesthetic and robust multiplayer capabilities.

---

## 🚀 Features

### 🎮 Three Distinct Game Modes
- **Offline Single Player**  
  Challenge smart AI bots without needing an internet connection.

- **Online Multiplayer**  
  Play with friends anywhere in the world using private **Room Codes** (powered by Firebase).

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
You **MUST** press the **“Niko Kadi”** warning button if you are left with:
- One card, or
- Multiple cards of the same rank  

Failure to do so results in a **+2 card penalty**.

### Cardless State
If you finish with a **Power Card**, you are **Cardless (0 cards)** but **haven’t won yet**.  
You must pick on your next turn.

---

## 🛠 Tech Stack

- **Framework:** Flutter (Dart)
- **Backend:**  
  - Firebase Firestore (Online state)  
  - Firebase Auth (Anonymous login)

- **Networking:**  
  - `web_socket_channel`  
  - `shelf` (Local LAN server)

- **State Management:**  
  - `setState`  
  - `StreamController` patterns

- **Persistence:**  
  - `shared_preferences` (Local stats & unlocks)

---

## 📦 Installation

### Clone the repository
```bash
git clone https://github.com/Iconia7/Kadi-Ke.git
```

### Install dependencies
```bash
flutter pub get
```

### Run the app
```bash
flutter run
```

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

### 📄 License

Distributed under the MIT License.
See LICENSE for more information.

### Made with ❤️ by Nexora Creative Solutions.