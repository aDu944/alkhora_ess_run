# iOS Setup Guide

## Fix CocoaPods Issue

The CocoaPods error occurs because it was installed with a different Ruby version. Here's how to fix it:

### Option 1: Reinstall CocoaPods (Recommended)

```bash
# Uninstall CocoaPods
sudo gem uninstall cocoapods

# Reinstall CocoaPods
sudo gem install cocoapods

# Setup CocoaPods
pod setup
```

### Option 2: Use Bundler (More Reliable)

```bash
# Install bundler if not already installed
gem install bundler

# Create a Gemfile in the ios directory
cd ios
bundle init

# Add CocoaPods to Gemfile
echo "gem 'cocoapods', '~> 1.15'" >> Gemfile

# Install dependencies
bundle install

# Use bundle exec for pod commands
bundle exec pod install
```

### Option 3: Use Homebrew (Alternative)

```bash
# Install CocoaPods via Homebrew
brew install cocoapods

# Navigate to ios directory and install pods
cd ios
pod install
```

## After Fixing CocoaPods

1. Navigate to the ios directory:
   ```bash
   cd ios
   ```

2. Install pods:
   ```bash
   pod install
   ```

3. Go back to project root and run:
   ```bash
   cd ..
   flutter run
   # Select option [2] for your iPhone
   ```

## Requirements

- Xcode installed and updated
- Your iPhone connected via USB
- Your iPhone trusted on your Mac
- Developer account configured in Xcode
- Code signing set up in Xcode (Team: D2X5C6Y7PL)

## Troubleshooting

If you still get errors:

1. Clean Flutter build:
   ```bash
   flutter clean
   flutter pub get
   ```

2. Clean iOS build:
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   ```

3. Open in Xcode and check code signing:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Select Runner target
   - Go to Signing & Capabilities
   - Ensure your team is selected
   - Ensure bundle identifier matches: `com.alkhora.alkhoraEss`

