#!/bin/zsh
# Builds a Developer ID signed, notarized and stapled installer package in dist/.
# Usage: NOTARY_PROFILE=<notarytool keychain profile> scripts/release.sh [--skip-notarize]
set -euo pipefail

cd "$(dirname "$0")/.."

TEAM_ID="LAR9U97K23"
BUNDLE_ID="com.sherrodsoftware.OSReport"
APP_NAME="OSReport"
INSTALLER_IDENTITY="Developer ID Installer: JOHN WILLIAM SHERROD (${TEAM_ID})"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
SKIP_NOTARIZE=false
[[ "${1:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=true

WORK="build/release"
ARCHIVE="${WORK}/${APP_NAME}.xcarchive"
EXPORT="${WORK}/export"
rm -rf "$WORK"
mkdir -p "$WORK" dist

echo "==> Archiving"
xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "$APP_NAME" -configuration Release \
    -archivePath "$ARCHIVE" -allowProvisioningUpdates archive -quiet

echo "==> Exporting with Developer ID"
cat > "${WORK}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
    -exportOptionsPlist "${WORK}/ExportOptions.plist" -allowProvisioningUpdates -quiet

APP="${EXPORT}/${APP_NAME}.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP}/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP}/Contents/Info.plist")
PKG="dist/${APP_NAME}-${VERSION}.pkg"
codesign --verify --deep --strict "$APP"

echo "==> Building ${PKG} (version ${VERSION}, build ${BUILD})"
ROOT="${WORK}/root"
mkdir -p "$ROOT"
ditto "$APP" "${ROOT}/${APP_NAME}.app"
COMPONENTS="${WORK}/components.plist"
pkgbuild --analyze --root "$ROOT" "$COMPONENTS" >/dev/null
/usr/libexec/PlistBuddy -c "Delete :0:BundleIsRelocatable" "$COMPONENTS" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$COMPONENTS"
rm -f "$PKG"
pkgbuild --root "$ROOT" --component-plist "$COMPONENTS" --install-location /Applications \
    --identifier "$BUNDLE_ID" --version "$VERSION" --sign "$INSTALLER_IDENTITY" "$PKG"

if $SKIP_NOTARIZE; then
    echo "==> Skipping notarization: ${PKG} is signed but not notarized"
    exit 0
fi

echo "==> Notarizing (this usually takes a few minutes)"
xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$PKG"

echo "==> Checking"
spctl -a -vv -t install "$PKG"
echo "Done: ${PKG}"
