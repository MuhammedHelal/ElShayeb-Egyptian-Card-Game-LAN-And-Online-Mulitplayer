# 🃏 ElShayeb - Egyptian card game LAN & Online multiplayer

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-green)
![Multiplayer](https://img.shields.io/badge/Multiplayer-LAN%20%26%20Online-orange)
![License](https://img.shields.io/badge/License-MIT-brightgreen)

ElShayeb is a modern digital implementation of the classic **Egyptian card game “El Shayeb”**, built with **Flutter**.  
The game supports **2 to 6 players** and offers both **LAN multiplayer** and **online multiplayer** gameplay with real-time synchronization.

---

## 📌 Project Overview

ElShayeb brings a traditional Egyptian card game into the modern digital world.  
Players can enjoy matches with friends locally over LAN or online, with smooth animations, sound effects, and responsive UI.

### Key Objectives
- Authentic ElShayeb rules
- Real-time multiplayer gameplay
- Cross-platform support
- Clean and scalable architecture

---

## 🧰 Tech Stack

### Core
- Flutter (Dart)
- flutter_bloc (BLoC Pattern)
- Equatable

### Networking & Multiplayer
- WebSocket Channel
- Multicast DNS (LAN discovery)
- UUID

### UI & Media
- flutter_svg
- audioplayers
- vibration

### Utilities
- get_it
- shared_preferences

---

## 🏗️ Architecture

```
UI (Widgets)
   ↓
BLoC (Game / Lobby / Network)
   ↓
Services (Networking, Audio, Storage)
   ↓
Models (Player, Card, Game State)
```

---

## ✨ Features

- 2–6 player multiplayer
- Online & LAN play
- Automatic LAN discovery
- SVG playing cards
- Sound effects & music
- Haptic feedback
- Real-time synchronization

---

## 🧪 Testing

```bash
flutter test
```

Includes unit tests, widget tests, and BLoC state validation.

---

## 📁 Folder Structure

```
elshayeb/
├── lib/
│   ├── blocs/
│   ├── models/
│   ├── services/
│   ├── ui/
│   ├── utils/
│   └── main.dart
├── assets/
│   ├── cards/
│   ├── sounds/
│   └── music/
├── test/
├── pubspec.yaml
└── README.md
```

---

## ▶️ How to Run

```bash
git clone https://github.com/your-username/elshayeb.git
cd elshayeb
flutter pub get
flutter run
```

---

## 🚀 Future Improvements

- AI / Bot players
- Leaderboards
- User profiles
- Matchmaking servers
- Game replays
- Anti-cheat system

---

## 📸 Screenshots

Screenshots will be added here.

---

## 🌐 Social Links

- GitHub: https://github.com/your-username/elshayeb
- Email: your-email@example.com

---

## ❤️ Contributing

Contributions are welcome!  
Feel free to open issues or submit pull requests.

---

Enjoy playing **ElShayeb** 🃏
