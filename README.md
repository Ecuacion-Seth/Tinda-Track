# Tinda-Track

A cross-platform Flutter application for tracking inventory and sales — built for small store owners who need a simple, offline-first solution to manage their products and monitor their business.

> **"Tinda"** is the Filipino word for *store* or *to sell* — Tinda-Track is your store's best companion.

---

## Features

- **Product Management** — Add, edit, and remove products with photos, names, prices, and stock quantities
- **Barcode Scanning** — Quickly look up or register products using your device's camera
- **Sales Tracking** — Record transactions and keep a running history of sales
- **Inventory Monitoring** — Keep tabs on stock levels and get a clear picture of what's running low
- **Analytics & Charts** — Visual summaries of sales trends and inventory data powered by fl_chart
- **Offline-First** — All data is stored locally on-device using SQLite — no internet required
- **Cross-Platform** — Runs on Android, iOS, Web, Windows, macOS, and Linux

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.11.4`
- Dart SDK `^3.11.4`
- Android Studio / Xcode (for mobile targets) or a compatible IDE (VS Code recommended)

Verify your setup:

```bash
flutter doctor
```

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/Ecuacion-Seth/Tinda-Track.git
   cd Tinda-Track
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**

   ```bash
   flutter run
   ```

   To target a specific platform:

   ```bash
   flutter run -d android   # Android device or emulator
   flutter run -d ios       # iOS device or simulator
   flutter run -d chrome    # Web (browser)
   flutter run -d windows   # Windows desktop
   ```

---

## Building for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

---

## Project Structure

```
lib/
├── main.dart           # App entry point
├── models/             # Data models (Product, Sale, etc.)
├── screens/            # UI screens and pages
├── widgets/            # Reusable UI components
├── providers/          # State management (Provider)
├── database/           # SQLite database helpers (sqflite)
└── utils/              # Utility functions and constants
```

> *Structure may vary — update this section as the project grows.*

---

## Dependencies

| Package | Purpose |
|---|---|
| [`sqflite`](https://pub.dev/packages/sqflite) | Local SQLite database for offline storage |
| [`path`](https://pub.dev/packages/path) | File path utilities |
| [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) | Barcode and QR code scanning |
| [`fl_chart`](https://pub.dev/packages/fl_chart) | Charts and data visualizations |
| [`image_picker`](https://pub.dev/packages/image_picker) | Pick product images from camera or gallery |
| [`provider`](https://pub.dev/packages/provider) | State management |
| [`uuid`](https://pub.dev/packages/uuid) | Unique ID generation |
| [`intl`](https://pub.dev/packages/intl) | Date formatting and internationalization |
| [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) | Custom app icon generation |

---

## Permissions

The app may request the following device permissions depending on features used:

- **Camera** — for barcode scanning and product photos
- **Photo Library / Storage** — for picking product images

---

## Contributing

Contributions are welcome! To get started:

1. Fork the repository
2. Create a new branch: `git checkout -b feature/your-feature-name`
3. Make your changes and commit: `git commit -m "Add your feature"`
4. Push to your branch: `git push origin feature/your-feature-name`
5. Open a Pull Request

Please make sure your code passes `flutter analyze` before submitting.

---

## License

This project is currently unlicensed. Add a `LICENSE` file to specify terms for use and distribution.

---

## Acknowledgements

- Built with [Flutter](https://flutter.dev/)
- Inspired by the everyday hustle of Filipino *tindahan* (small store) owners
