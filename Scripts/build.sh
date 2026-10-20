#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# This is a generated bundle; rebuild it fresh so removed upstream resources cannot linger.
rm -rf .build/App/Build/Products/Release/SecurePaste.app
xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath .build/App -clonedSourcePackagesDirPath .build/SourcePackages -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build
# Xcode may retain this removed upstream icon in its intermediate asset catalog output.
rm -f .build/App/Build/Products/Release/SecurePaste.app/Contents/Resources/AppIcon.icns
/usr/bin/codesign --force --sign - --options runtime --timestamp=none --entitlements Maccy/Maccy.entitlements .build/App/Build/Products/Release/SecurePaste.app
/usr/bin/codesign --verify --deep --strict .build/App/Build/Products/Release/SecurePaste.app
print -r -- "Application : ${PWD}/.build/App/Build/Products/Release/SecurePaste.app"
