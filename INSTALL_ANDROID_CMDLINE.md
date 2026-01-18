# Install Android Command-Line Tools

## Quick Setup

Your Android SDK is located at: `~/Library/Android/sdk`

### Method 1: Via Android Studio (Easiest)

1. Open **Android Studio**
2. Go to **Tools → SDK Manager** (or press `Cmd+,` then select "Android SDK")
3. Click on the **SDK Tools** tab
4. Check the box for **Android SDK Command-line Tools (latest)**
5. Click **Apply** or **OK**
6. Wait for the installation to complete

After installation, you should see:
- `~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager`

### Method 2: Manual Installation

If you prefer to install manually:

1. **Download command-line tools:**
   - Visit: https://developer.android.com/studio#command-line-tools-only
   - Download "Command line tools for Mac" (ZIP file)

2. **Extract and install:**
   ```bash
   # Create cmdline-tools directory
   mkdir -p ~/Library/Android/sdk/cmdline-tools
   
   # Extract the downloaded ZIP file
   # The ZIP contains a folder like "cmdline-tools" or "tools"
   # If it contains "tools", rename it to "latest"
   # If it contains "cmdline-tools", extract it and rename the inner folder to "latest"
   
   # Example (adjust based on what's in the ZIP):
   cd ~/Downloads
   unzip commandlinetools-mac-*.zip
   # If it extracts to "cmdline-tools", do:
   mv cmdline-tools ~/Library/Android/sdk/cmdline-tools/latest
   # OR if it extracts to "tools", do:
   mkdir -p ~/Library/Android/sdk/cmdline-tools
   mv tools ~/Library/Android/sdk/cmdline-tools/latest
   ```

3. **Set environment variables:**
   ```bash
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
   
   # Add to ~/.zshrc to make permanent
   echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
   echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.zshrc
   
   # Reload shell
   source ~/.zshrc
   ```

4. **Verify installation:**
   ```bash
   sdkmanager --version
   ```

## After Installing Command-Line Tools

1. **Accept Android licenses:**
   ```bash
   flutter doctor --android-licenses
   ```
   Or:
   ```bash
   yes | sdkmanager --licenses
   ```

2. **Verify flutter doctor:**
   ```bash
   flutter doctor -v
   ```

You should now see:
- ✅ Android toolchain - develop for Android devices
- All checks passing
