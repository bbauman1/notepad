# Notepad

A cross-platform note-taking application built with SwiftUI and Convex, featuring real-time sync across iOS and macOS devices.

## Features

- **Cross-Platform**: Native iOS and macOS apps with shared business logic
- **Real-Time Sync**: Instant synchronization across all your devices using Convex
- **Auto-Save**: Automatic saving with debounced updates to prevent data loss
- **Authentication**: Secure user authentication with BetterAuth
- **Clean UI**: Platform-specific interfaces optimized for iOS and macOS
- **Keyboard Shortcuts**: macOS-native keyboard shortcuts for power users
- **Search**: Searchable notes with quick access menu

## Tech Stack

### Frontend
- **Language**: Swift
- **Framework**: SwiftUI
- **Platforms**: iOS 16.0+, macOS 13.0+
- **Dependencies**:
  - ConvexMobile (real-time database client)
  - BetterAuth (authentication)

### Backend
- **Platform**: Convex (serverless backend)
- **Language**: TypeScript
- **Database**: Convex real-time database
- **Authentication**: BetterAuth with custom provider

## Prerequisites

- Xcode 14.0 or later
- macOS 13.0 or later (for development)
- Node.js 16+ and npm
- A Convex account (sign up at [convex.dev](https://convex.dev))
- A BetterAuth server (or deploy your own)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/notepad.git
cd notepad
```

### 2. Set Up Convex Backend

```bash
# Install dependencies
npm install

# Set up Convex (follow the prompts to create/link a project)
npx convex dev
```

This will create a `.env.local` file with your Convex deployment credentials.

### 3. Configure Environment Variables

Copy the example environment file and fill in your values:

```bash
cp .env.example .env.local
```

Edit `.env.local` with your Convex deployment information:

```bash
CONVEX_DEPLOYMENT=dev:your-deployment-name
CONVEX_URL=https://your-deployment-name.convex.cloud
```

### 4. Configure Auth Server (Optional)

If you're running your own BetterAuth server, update the URLs in:
- `Notepad/Config/Config.swift` - Update `authServerURL`
- `convex/auth.config.ts` - Update `domain`

### 5. Open in Xcode

```bash
open Notepad.xcodeproj
```

### 6. Update Bundle Identifier (Optional)

If you want to use your own bundle identifier:
1. Open the project in Xcode
2. Select the Notepad target
3. Update the Bundle Identifier in the "Signing & Capabilities" tab
4. Update the URL scheme in `Info.plist` if needed

## Running the App

### Development Mode

1. Start the Convex backend:
```bash
npx convex dev
```

2. In Xcode, select your target device (iOS Simulator or Mac)
3. Press `Cmd+R` to build and run

### Production Deployment

1. Deploy your Convex backend:
```bash
npx convex deploy
```

2. Update `Config.swift` to use your production Convex URL
3. Archive and distribute your app through Xcode

## Project Structure

```
Notepad/
├── Notepad/                    # iOS/macOS app source
│   ├── Config/                 # Configuration files
│   ├── Models/                 # Data models (Note, User)
│   ├── Services/               # Business logic
│   │   ├── AuthService.swift           # Authentication management
│   │   ├── ConvexService.swift         # Convex client wrapper
│   │   ├── BetterAuthProvider.swift    # OAuth provider
│   │   ├── AutoSaveService.swift       # Auto-save functionality
│   │   └── NoteSubscriptionService.swift # Real-time sync
│   ├── Views/                  # SwiftUI views
│   │   ├── Shared/             # Cross-platform views
│   │   ├── iOS/                # iOS-specific views
│   │   └── macOS/              # macOS-specific views
│   ├── Utilities/              # Helper utilities
│   └── NotepadApp.swift        # App entry point
│
├── convex/                     # Backend code
│   ├── schema.ts               # Database schema
│   ├── notes.ts                # CRUD operations
│   ├── auth.config.ts          # Auth configuration
│   └── lib/                    # Helper utilities
│
└── package.json                # Node.js dependencies
```

## Architecture

### Frontend
- **State Management**: SwiftUI's `@StateObject` and `@EnvironmentObject`
- **Authentication Flow**: BetterAuth OAuth → JWT in Keychain → Convex Login
- **Real-Time Sync**: ConvexMobile WebSocket subscriptions
- **Platform-Specific**: Separate view implementations for iOS and macOS

### Backend
- **Database**: Single `notes` table with user-based access control
- **Security**: Server-side auth verification via `getAuthUserId()`
- **Real-Time**: Automatic WebSocket updates via Convex queries

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Backend powered by [Convex](https://convex.dev)
- Authentication via [BetterAuth](https://www.better-auth.com)
