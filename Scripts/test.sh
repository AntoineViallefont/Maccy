#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift test --package-path Packages/SecurePasteKit
xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Debug -derivedDataPath .build/App -clonedSourcePackagesDirPath .build/SourcePackages -onlyUsePackageVersionsFromResolvedFile -destination 'platform=macOS' -only-testing:MaccyTests/ShortenedTests -only-testing:MaccyTests/CollectionSurroundingTests -only-testing:MaccyTests/UnsafeForTitleLayoutTests -only-testing:MaccyTests/IntentBoundsTests CODE_SIGNING_ALLOWED=NO test
