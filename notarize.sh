IDENTITY="Developer ID Application: Aidan Rodriguez (XCZH84J8HN)"  # Replace with your actual identity
INSTALLER_IDENTITY="Developer ID Installer: Aidan Rodriguez (XCZH84J8HN)"
INSTALLER_PROFILE="InstallerNotary"
ASP_PASSWORD="rwik-gkzm-hwbi-kazk"    # Store your app-specific password in Keychain
BUNDLE_ID="com.aidanrodriguez.hitcrate"    # Replace with your actual bundle ID
KEYCHAIN_PROFILE="DevNotary"
APP_PATH="dist/Hit Crate.app"
ENTITLEMENTS_PATH="entitlements.plist"  # Create this file if needed
DMG_NAME="dist/Hit Crate.dmg"
ZIP_NAME="dist/Hit Crate.zip"


# cd ~/documents/github/hit-crate
# rm -rf dist
# rm -rf build
#
# python3 setup.py py2app


echo "Unzipping necessary files"
cd "../dist/Hit Crate.app/Contents/Resources/lib"
unzip python313.zip -d python3.13
rm python313.zip

cd "python3.13/pygame/docs/generated/_static"
unzip legacy_logos.zip -d legacy_logos
rm legacy_logos.zip
cd ..
cd ..
cd ..
cd ..
cd ..
cd "python3.13/pkg_resources/tests/data/my-test-package-zip"
unzip my-test-package.zip -d my-test-package
rm my-test-package.zip

echo "Unzipping finished"

cd ~/documents/github/hit-crate

echo "📝 Signing all binaries and frameworks..."

# First, sign individual files inside the app
find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.so" -o -path "*.framework/*" \) | while read -r file; do
    if [[ ! -L "$file" && -f "$file" ]]; then
        echo "Signing $file"
        codesign --force --options runtime --timestamp --sign "$IDENTITY" "$file"
    fi
done

# Signing .dylib files inside the .zip
echo "📝 Signing individual dylibs in python313.zip..."

find "$APP_PATH/Contents/Resources/lib/python313.zip" -type f -name "*.dylib" | while read -r file; do
    if [[ -f "$file" ]]; then
        echo "Signing $file"
        codesign --force --options runtime --sign "$IDENTITY" --timestamp "$file"
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
codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS_PATH" --timestamp --sign "$IDENTITY" "$APP_PATH"

echo "✅ Verifying signature..."
codesign --verify --verbose "$APP_PATH"

echo "🔍 Running spctl assessment..."
spctl --assess --verbose=4 "$APP_PATH"



# echo "📦 Zipping the .app bundle..."
# rm -f "$ZIP_NAME"
# ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_NAME"
#
# echo "📤 Submitting ZIP for notarization..."
# xcrun notarytool submit "$ZIP_NAME" --keychain-profile "$KEYCHAIN_PROFILE" --wait

PKG_NAME="HitCrateInstaller.pkg"
/usr/bin/productbuild \
  --component "$APP_PATH" /Applications \
  --sign "$INSTALLER_IDENTITY" \
  "$PKG_NAME"

echo "📤 Submitting .pkg for notarization..."
xcrun notarytool submit "$PKG_NAME" --keychain-profile "$INSTALLER_PROFILE" --wait
xcrun stapler staple "$PKG_NAME"

# echo "📎 Stapling the .app..."
# xcrun stapler staple "$APP_PATH"

# echo "📦 Creating DMG using create-dmg..."
# rm -f "$DMG_NAME"
# create-dmg --app-drop-link 150 150 "$DMG_NAME" "$APP_PATH"
#
# echo "📝 Signing the DMG..."
# codesign --force --sign "$IDENTITY" --timestamp "$DMG_NAME"
#
# echo "📎 Stapling the notarization ticket to DMG..."
# xcrun stapler staple "$DMG_NAME"

echo "✅ Done"
