# 🎙️ Nota AI - Voice Notes

A beautiful, modern AI-powered voice notes app that intelligently organizes your thoughts. Built with Flutter.

**App Name:** Nota AI  
**Full Name:** Nota AI - Voice Notes  
**Version:** 1.0.0

## ✨ Features

- **Voice Recording**: Press and hold the microphone button to record your notes
- **AI Transcription**: Powered by OpenAI Whisper for accurate transcription
- **Smart Organization**: GPT automatically organizes your notes under relevant headlines
- **Beautiful UI**: Modern black & white design inspired by Notion
- **Smooth Animations**: Delightful micro-interactions throughout the app
- **Local Storage**: All notes are saved locally on your device

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (^3.9.2)
- OpenAI API key ([Get one here](https://platform.openai.com))

### Installation

1. Clone or open this repository

2. Create a `.env` file in the root directory:
   ```bash
   cp .env.example .env
   ```

3. Add your OpenAI API key to the `.env` file:
   ```
   OPENAI_API_KEY=sk-your-actual-api-key-here
   ```
   Get your API key from: https://platform.openai.com

4. Install dependencies:
   ```bash
   flutter pub get
   ```

5. Run the app:
   ```bash
   flutter run
   ```

## 📱 How to Use

### Recording a Note

1. **Press and hold** the microphone button at the bottom of the screen
2. Speak your note
3. **Release** to stop recording
4. The app will automatically transcribe your audio

### Organizing Notes

1. After recording, select an existing note or create a new one
2. Give your note a name and choose an icon
3. The AI will analyze your transcription and either:
   - Place it under an existing headline that fits
   - Create a new headline with the perfect scope

### Viewing Notes

- Tap any note card on the home screen to view its contents
- Notes are organized by headlines
- Each entry shows the transcribed text and timestamp

## 🎨 Design Philosophy

This app follows a minimalist, professional design inspired by Notion:

- **Black & White Color Scheme**: Clean, timeless, and distraction-free
- **Inter Font**: Modern, readable typography
- **Smooth Animations**: 200-300ms transitions for a fluid experience
- **Touch-Optimized**: Large tap targets and intuitive gestures
- **Consistent Spacing**: 4px grid system for visual harmony

## 🛠️ Technical Stack

- **Framework**: Flutter
- **State Management**: Provider
- **Audio Recording**: record package
- **Storage**: shared_preferences
- **AI Services**: OpenAI Whisper + GPT-4o-mini
- **Animations**: flutter_animate
- **Fonts**: Google Fonts (Inter)

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── note.dart            # Data models (Note, Headline, TextEntry)
├── providers/
│   └── notes_provider.dart  # State management
├── services/
│   ├── storage_service.dart # Local data persistence
│   └── openai_service.dart  # AI transcription & organization
├── screens/
│   ├── home_screen.dart     # Main screen with notes list
│   └── note_detail_screen.dart  # Note viewing screen
├── widgets/
│   ├── microphone_button.dart      # Recording button
│   ├── note_card.dart              # Note list item
│   ├── note_selection_sheet.dart   # Note picker
│   └── create_note_dialog.dart     # Note creation
└── theme/
    └── app_theme.dart       # App-wide styling
```

## 🔒 Privacy & Security

- Your API key is stored in a local `.env` file (not committed to git)
- Notes are saved only on your device
- Audio recordings are temporary and deleted after transcription
- No data is sent to any server except OpenAI for transcription/organization

**⚠️ Important Security Notes:**
- Never commit your `.env` file to version control (already in `.gitignore`)
- API keys bundled in the app can be extracted - see [SECURITY.md](SECURITY.md) for details
- For production apps, consider implementing a backend proxy (see security documentation)
- Use different API keys for development and production
- Monitor API usage and set up billing alerts

**📚 Read the full [Security Guidelines](SECURITY.md)** for production deployment best practices.

## 💰 Cost Estimation

OpenAI API costs (as of 2024):
- **Whisper**: ~$0.006 per minute of audio
- **GPT-4o-mini**: ~$0.0015 per request

Example: 100 voice notes (average 30 seconds each) = ~$0.50/month

## 🚀 Publishing to App Store

### iOS

1. App configuration (already set):
   - ✅ `CFBundleDisplayName`: "Nota AI - Voice Notes"
   - ✅ `CFBundleName`: "Nota AI"
   - ✅ Microphone permission with description
   - ✅ Orientation locked to portrait
   - Update bundle identifier to your own

2. Build for release:
   ```bash
   flutter build ios --release
   ```

3. Submit through Xcode

**Note:** See [SECURITY.md](SECURITY.md) for important production security considerations.

### Android

1. Update `android/app/src/main/AndroidManifest.xml`:
   - Set app label

2. Build for release:
   ```bash
   flutter build appbundle --release
   ```

3. Submit to Google Play Console

## 🤝 Support

For issues or questions:
1. Check that your OpenAI API key is valid
2. Ensure microphone permissions are granted
3. Verify internet connection for API calls

## 📄 License

This project is ready for immediate deployment to app stores.

---

Built with ❤️ using Flutter
