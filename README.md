# Notepad

A cross-platform notepad built with SwiftUI, Convex, and Better Auth.

The Convex Swift SDK does not yet natively support BetterAuth, so this project shows how to make that work.

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/bbauman1/notepad.git
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

### 4. Configure Auth Server

I have a separate repo for the auth server, located [here](https://github.com/bbauman1/notepad-auth):
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- Thank you to [BetterAuthSwift](https://github.com/ouwargui/BetterAuthSwift) for making the basic BetterAuth connection much simpler.
