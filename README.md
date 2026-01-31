# PR Reviewer - iPhone 13 Mini

Personal-use iOS app for reviewing GitHub Pull Requests on iPhone 13 Mini.

## Features

- View all open PRs you're involved in (author, reviewer, mentioned)
- Swipe horizontally between PRs
- View diffs with dark red/green backgrounds for deletions/additions
- Full PR description with markdown at top of code view
- Full-width code display (no navigation overlays)
- Inline comments below code (never overlapping)
- Resolve comments with a "Resolve" button (hides them locally)
- 5-minute unresolve window to undo accidental resolutions
- Swipe right to close PR (with confirmation)
- Swipe left to approve PR (checks merge conflicts first)
- Multi-account support (up to 5 GitHub accounts)
- Local notifications for new commits/comments (not by you)
- Tap notifications to jump directly to the PR and comment location
- Auto-refresh every 5 minutes
- Landscape-only for maximum code visibility

## Requirements

- macOS with Xcode 15+
- Apple ID (free account works)
- iPhone 13 Mini with iOS 17+
- USB cable (Lightning or USB-C depending on your Mac)

## Build & Install Instructions

### Step 1: Open Project in Xcode

```bash
open PRReviewer.xcodeproj
```

Or double-click `PRReviewer.xcodeproj` in Finder.

### Step 2: Configure Signing

1. In Xcode, click on the **PRReviewer** project in the left sidebar
2. Select the **PRReviewer** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. For **Team**, select your Apple ID (or click "Add Account..." to sign in)
   - If you don't see your Apple ID, go to **Xcode → Settings → Accounts** and add it

### Step 3: Connect Your iPhone

1. Connect iPhone 13 Mini to Mac via USB cable
2. On iPhone: tap **Trust** when prompted to trust this computer
3. Enter your iPhone passcode if asked

### Step 4: Select Your Device

1. In Xcode's top toolbar, click the device dropdown (currently shows "Any iOS Device")
2. Under **iOS Devices**, select your **iPhone 13 mini**

### Step 5: Build & Run

1. Press **Cmd+R** or click the Play button
2. Wait for the build to complete and app to install
3. **First time only:** On your iPhone, go to:
   - **Settings → General → VPN & Device Management**
   - Tap your developer certificate
   - Tap **Trust**

### Step 6: Configure the App

1. Open the app on your iPhone
2. Tap **Open Settings**
3. Enter your GitHub username
4. Enter your Personal Access Token:
   - Go to https://github.com/settings/tokens
   - Generate new token (classic)
   - Select scope: `repo` (full control of private repositories)
   - Copy the token and paste it in the app
5. Toggle notification sound preference
6. Tap **Save Settings**

## Usage

### Viewing PRs
- Swipe left/right to navigate between PRs
- Pull down to refresh
- Tap the gear icon for settings

### Navigating Diffs
- Expand/collapse files by tapping the file header
- Use the side buttons to jump to next/previous change or comment
- Comments appear inline below the relevant code line
- Only changed lines are shown (no context lines)

### PR Actions
- **Swipe right** → Close PR (with confirmation)
- **Swipe left** → Approve PR (checks for merge conflicts first)
- If PR has conflicts or is behind target branch, approval is blocked

### Notifications
- The app checks for new activity every 5 minutes while open
- You'll get a notification when someone (not you) adds a commit or comment
- Notifications show the repository name, PR number, author, and content preview
- **Tap a notification** to open the app and jump directly to that PR and location
- Enable/disable notification sound in Settings

## Weekly Rebuild

With a free Apple ID, apps expire after 7 days. To reinstall:

1. Connect iPhone to Mac
2. Open project in Xcode
3. Press **Cmd+R**

That's it - no code changes needed.

## Command Line Build (Optional)

If you want to build from terminal instead of Xcode GUI:

```bash
# First, point xcode-select to Xcode (one-time setup)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Then build
make build
```

## Troubleshooting

### "Unable to install" error
- Make sure your iPhone is unlocked
- Try disconnecting and reconnecting USB
- Restart Xcode

### "Untrusted Developer" error
- Go to Settings → General → VPN & Device Management
- Trust your developer certificate

### App won't open after 7 days
- Normal behavior with free Apple ID
- Just rebuild from Xcode

### API errors
- Check your token has `repo` scope
- Verify token hasn't expired
- Check GitHub status at githubstatus.com

## Privacy

- Your GitHub token is stored securely in iOS Keychain
- Token is never displayed after entry
- All data stays on your device
- No analytics or tracking
