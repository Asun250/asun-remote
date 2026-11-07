#!/bin/bash
set -euo pipefail

# Run on a Mac/cloud Mac. Signing happens later in Sideloadly on Windows.
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build script needs macOS and Xcode. On Windows, use the included GitHub Actions workflow." >&2
  exit 1
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
build_directory="$project_root/DerivedData"
output_directory="$project_root/dist"
mkdir -p "$output_directory"

xcodebuild -quiet \
  -project AsunRemote.xcodeproj \
  -scheme AsunRemote \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$build_directory" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  'CODE_SIGN_IDENTITY=' \
  'DEVELOPMENT_TEAM=' \
  build

application="$build_directory/Build/Products/Release-iphoneos/AsunRemote.app"
if [[ ! -d "$application" ]]; then
  echo "Xcode did not produce the iPhone app bundle." >&2
  exit 1
fi
platform="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$application/Info.plist")"
if [[ "$platform" != "iPhoneOS" ]]; then
  echo "Refusing to package a Simulator app as an iPhone IPA." >&2
  exit 1
fi
executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$application/Info.plist")"
architectures="$(xcrun lipo -archs "$application/$executable")"
case " $architectures " in
  *" arm64 "*) ;;
  *) echo "The app is missing its iPhone arm64 executable." >&2; exit 1 ;;
esac

staging_directory="$(mktemp -d "${TMPDIR:-/tmp}/asun-remote.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT
mkdir -p "$staging_directory/Payload"
ditto "$application" "$staging_directory/Payload/AsunRemote.app"
ditto -c -k --keepParent "$staging_directory/Payload" "$output_directory/AsunRemote-unsigned.ipa"
(
  cd "$output_directory"
  shasum -a 256 AsunRemote-unsigned.ipa > SHA256SUMS.txt
)
echo "Created dist/AsunRemote-unsigned.ipa. Install and sign this file using Sideloadly on Windows."
