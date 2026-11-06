#!/usr/bin/env bash
# Generates android/ and ios/ folders and adds the permissions SkillBridge needs.
# Run once from the app folder:  bash setup_platforms.sh
set -euo pipefail

flutter create --org app.skillbridge --project-name skillbridge --platforms=android,ios .
rm -f test/widget_test.dart   # default counter test does not apply

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q ACCESS_FINE_LOCATION "$MANIFEST"; then
  perl -0pi -e 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <uses-permission android:name="android.permission.CAMERA"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <queries>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n    </queries>\n    <application|' "$MANIFEST"
fi

# Firebase needs minSdk 23.
GRADLE=$(ls android/app/build.gradle* | head -1)
perl -pi -e 's/minSdk\s*=?\s*flutter\.minSdkVersion/minSdk = 23/' "$GRADLE"

PLIST=ios/Runner/Info.plist
add_plist() {
  /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST" 2>/dev/null || true
}
if [[ "$(uname)" == "Darwin" ]]; then
  add_plist NSLocationWhenInUseUsageDescription "SkillBridge uses your location to find nearby providers and to share it if you press SOS."
  add_plist NSCameraUsageDescription "SkillBridge uses the camera for your ID selfie and job photos."
  add_plist NSPhotoLibraryUsageDescription "SkillBridge lets you attach photos of the job and your past work."
  perl -pi -e "s/# platform :ios, '.*'/platform :ios, '13.0'/" ios/Podfile 2>/dev/null || true
else
  echo "Not on macOS: add NSLocationWhenInUseUsageDescription, NSCameraUsageDescription and NSPhotoLibraryUsageDescription to $PLIST yourself."
fi

flutter pub get
echo "Done. Next: flutterfire configure"
