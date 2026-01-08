# Dubai Font Setup

The app uses the Dubai font for Arabic text. You need to add the font files to the project.

## Steps:

1. Download the Dubai font files:
   - Dubai-Regular.ttf
   - Dubai-Bold.ttf

2. Create a `fonts` directory in the project root (if it doesn't exist):
   ```bash
   mkdir fonts
   ```

3. Place the font files in the `fonts` directory:
   ```
   fonts/
     ├── Dubai-Regular.ttf
     └── Dubai-Bold.ttf
   ```

4. The `pubspec.yaml` is already configured to use these fonts. After adding the files, run:
   ```bash
   flutter pub get
   ```

5. The app will automatically use Dubai font when the language is set to Arabic.

## Note:
If you don't have the Dubai font files, you can:
- Purchase/download from the official source
- Use a similar Arabic font as a replacement
- The app will fall back to the system default font if Dubai is not found

