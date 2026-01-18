# Flutter Doctor Fix Guide

This guide will help you fix the issues shown by `flutter doctor`.

## Issues Found

1. ❌ CocoaPods not installed (for iOS development)
2. ❌ Android cmdline-tools component missing
3. ❌ Android license status unknown

---

## Fix 1: Install CocoaPods (iOS)

Choose one of these methods:

### Option A: Install via Homebrew (Recommended)
```bash
brew install cocoapods
```

If you get permission errors:
```bash
# Fix Homebrew permissions first
sudo chown -R $(whoami) /usr/local/Cellar
brew install cocoapods
```

### Option B: Install via Ruby Gems
```bash
sudo gem install cocoapods
pod setup
```

### Option C: Use Bundler (Most Reliable)
```bash
# Install bundler
gem install bundler

# Navigate to ios directory
cd ios

# Create Gemfile
bundle init

# Add CocoaPods to Gemfile
echo "gem 'cocoapods', '~> 1.15'" >> Gemfile

# Install dependencies
bundle install

# Use bundle exec for pod commands
bundle exec pod install

# Go back to project root
cd ..
```

### After Installing CocoaPods

1. Navigate to ios directory:
```bash
cd ios
```

2. Install pods:
```bash
pod install
```

3. Go back to project root:
```bash
cd ..
```

---

## Fix 2: Install Android Command-Line Tools

### Option A: Install via Android Studio (Recommended)

1. Open Android Studio
2. Go to **Tools → SDK Manager**
3. Click on **SDK Tools** tab
4. Check **Android SDK Command-line Tools (latest)**
5. Click **Apply** and wait for installation

### Option B: Install via Command Line

1. Set ANDROID_HOME if not set:
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
```

2. Download command-line tools manually:
   - Visit: https://developer.android.com/studio#command-line-tools-only
   - Download for macOS
   - Extract and place in: `$ANDROID_HOME/cmdline-tools/latest/`

3. Add to PATH:
```bash
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.zshrc

# Reload shell
source ~/.zshrc
```

---

## Fix 3: Accept Android Licenses

After installing command-line tools, accept the licenses:

```bash
flutter doctor --android-licenses
```

Or if that doesn't work:
```bash
yes | sdkmanager --licenses
```

You might need to set ANDROID_HOME first:
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
```

---

## Verify Everything Works

Run flutter doctor again:
```bash
flutter doctor -v
```

You should see:
- ✅ Flutter
- ✅ Android toolchain (all checks passing)
- ✅ Xcode (CocoaPods installed)
- ✅ Chrome
- ✅ Connected device(s)

---

## Quick Fix Script

Run all fixes in one go (copy and paste into terminal):

```bash
# Fix CocoaPods
brew install cocoapods || sudo gem install cocoapods

# Setup CocoaPods
pod setup

# Set Android paths
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin

# Install Android command-line tools (if needed)
# Note: You may need to do this via Android Studio instead

# Accept Android licenses
flutter doctor --android-licenses

# Install iOS pods
cd ios && pod install && cd ..

# Verify
flutter doctor -v
```

---

## Notes

- **CocoaPods**: Required for iOS development. You'll need it if you want to run on your iPhone or iOS simulator.
- **Android cmdline-tools**: Required for Android development. The easiest way is via Android Studio.
- **Android licenses**: Must be accepted once. After accepting, they stay accepted.
- These warnings won't prevent your app from building if you're only targeting one platform, but it's good to fix them all for full development capability.
