#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Release -derivedDataPath .build/App -clonedSourcePackagesDirPath .build/SourcePackages -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build
/usr/bin/codesign --force --sign - --options runtime --timestamp=none --entitlements Maccy/Maccy.entitlements .build/App/Build/Products/Release/SecurePaste.app
/usr/bin/codesign --verify --deep --strict .build/App/Build/Products/Release/SecurePaste.app
print -r -- "Application : ${PWD}/.build/App/Build/Products/Release/SecurePaste.app"
