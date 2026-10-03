# 🃏 ElShayeb - Egyptian card game LAN & Online multiplayer

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-green)
![Multiplayer](https://img.shields.io/badge/Multiplayer-LAN%20%26%20Online-orange)
![License](https://img.shields.io/badge/License-MIT-brightgreen)

ElShayeb is a modern digital implementation of the classic **Egyptian card game “El Shayeb”**, built with **Flutter**.  
The game supports **2 to 6 players** and offers both **LAN multiplayer** and **online multiplayer** gameplay with real-time synchronization.

---

## 📸 Screenshots

| Lobby | Create Room | LAN Automatic discovery |
|---------|--------|-------|
| ![](https://github.com/user-attachments/assets/3428a150-1de4-44d9-a5c4-e88a87838ce7) | ![](https://github.com/user-attachments/assets/4344c07d-4a4b-46b8-99a1-5370cc682aa4) | ![](https://github.com/user-attachments/assets/327d9dad-ff75-4b47-9a42-d88d8c47e137) |

| Game Screen | Matching Cards | Round Results |
|------------|-----------|-------------|
| ![](https://github.com/user-attachments/assets/6a60dc25-a212-49a6-91a9-6353a19dca4f) | ![](https://github.com/user-attachments/assets/c8c176bf-bd0f-4a62-8067-4bb3476a9363) | ![](https://github.com/user-attachments/assets/44ac4fcf-506a-455d-9381-f6538f928887) |

| Settings | Game Rules | Multiplayer |
|----------|---------|-------------|
| ![](https://github.com/user-attachments/assets/87f3cc8b-dae0-41c1-b202-fea0159bc16e) | ![](https://github.com/user-attachments/assets/d8e2e135-b8fe-44eb-a099-a164cf28340b) |![WhatsApp Image 2025-12-25 at 1 53 58 AM (3)](https://github.com/user-attachments/assets/4ca242af-89de-4a56-93a8-f811f294773c)
  |

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

### Cloudflare online lobby test

The server-authoritative online path is currently enabled only for lobby
testing. Run the app with:

```bash
flutter run --dart-define=DURABLE_OBJECT_ONLINE=true
```

The **Online** button will then open the Cloudflare Durable Objects lobby.
Create a room on one device and join its six-character code from another.
Card gameplay remains on the legacy path until the rules have been moved to
the server and its private player views are ready.

---

## 🚀 Future Improvements

- AI / Bot players
- Leaderboards
- User profiles
- Matchmaking servers
- Game replays
- Anti-cheat system

---

## 🌐 Social Links
- Email: muhdashrafatef@gmail.com

---

## ❤️ Contributing

Contributions are welcome!  
Feel free to open issues or submit pull requests.

---

Enjoy playing **ElShayeb** 🃏
