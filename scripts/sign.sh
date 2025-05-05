APP_PATH="Hit Crate.app"
IDENTITY="Developer ID Application: Aidan Rodriguez (XCZH84J8HN)"  # Replace with your actual identity
ENTITLEMENTS_PATH="entitlements.plist"  # Create this file if needed
BUNDLE_ID="com.aidanrodriguez.hitcrate"    # Replace with your actual bundle ID
ASP_PASSWORD="rwik-gkzm-hwbi-kazk"    # Store your app-specific password in Keychain
DMG_NAME="Hit Crate.dmg"
KEYCHAIN_PROFILE="DevNotary"

echo "📝 Signing all binaries and frameworks..."

# First, sign individual files inside the app
find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.so" -o -path "*.framework/*" \) | while read -r file; do
    if [[ ! -L "$file" && -f "$file" ]]; then
        echo "Signing $file"
        codesign --force --options runtime --timestamp --sign "$IDENTITY" "$file"
    fi
done

# Explicitly sign known binaries inside the .app before the final bundle signing
BINARIES=(
  "$APP_PATH/Contents/MacOS/python"
  "$APP_PATH/Contents/MacOS/Hit Crate"
)

for bin in "${BINARIES[@]}"; do
    if [[ -f "$bin" ]]; then
        echo "Signing binary: $bin"
        codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS_PATH" --sign "$IDENTITY" "$bin"
    fi
done

echo "📝 Signing the main app bundle..."
codesign --force --options runtime --entitlements "$ENTITLEMENTS_PATH" --timestamp --sign "$IDENTITY" "$APP_PATH"

echo "✅ Verifying signature..."
codesign --verify --verbose "$APP_PATH"

echo "🔍 Running spctl assessment..."
spctl --assess --verbose=4 "$APP_PATH"

echo "📦 Creating DMG using create-dmg..."
# Remove existing DMG if it exists
rm -f "$DMG_NAME"

# Create a DMG with app drop link
create-dmg --app-drop-link 150 150 "$DMG_NAME" "$APP_PATH"

echo "📝 Signing the DMG..."
codesign --force --sign "$IDENTITY" --timestamp "$DMG_NAME"

echo "📤 Submitting for notarization..."
xcrun notarytool submit "$DMG_NAME" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "🔍 Stapling the notarization ticket to DMG..."
xcrun stapler staple "$DMG_NAME"

echo "✅ Done"
