# Enable Developer Mode on iPhone

## Error Message
```
error:Developer Mode disabled To use Ahmed iPhone for development, enable Developer Mode in Settings → Privacy & Security.
```

## Solution: Enable Developer Mode

1. **On your iPhone**, open the **Settings** app

2. Navigate to:
   - **Settings** → **Privacy & Security** → **Developer Mode**
   
   OR
   
   - **Settings** → **General** → **VPN & Device Management** → **Developer Mode**

3. **Toggle ON** the "Developer Mode" switch

4. Your iPhone will **restart** automatically

5. After restart, unlock your iPhone and you'll see a popup asking:
   - **"Turn On Developer Mode?"**
   - Tap **"Turn On"**

6. Enter your **passcode** when prompted

7. Wait for the iPhone to **restart again**

8. After the second restart, Developer Mode will be enabled

## After Enabling Developer Mode

1. **Connect your iPhone** to your Mac via USB cable

2. **Trust the computer** on your iPhone if prompted:
   - Tap "Trust" when you see "Trust This Computer?"
   - Enter your iPhone passcode

3. **Run Flutter again:**
   ```bash
   flutter run
   ```
   
4. Select option **[2]** for your iPhone

## Verification

You can verify Developer Mode is enabled by:
- Going to **Settings** → **Privacy & Security** → **Developer Mode**
- The switch should be **ON** and **green**

## Troubleshooting

If you don't see Developer Mode option:
1. Make sure you have **Xcode installed** on your Mac
2. Make sure you've accepted the **Xcode license**: `sudo xcodebuild -license accept`
3. Try **unplugging and reconnecting** your iPhone
4. Restart your iPhone

## Notes

- Developer Mode was introduced in iOS 16+
- Your iPhone will need to restart twice when enabling Developer Mode
- You need to unlock your iPhone after each restart to complete the setup
- Once enabled, Developer Mode stays on until you manually disable it
