#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ui-module-cache
# This harness has no Store and cannot read or write character, compendium, or activity files.
xcrun swiftc -module-cache-path build/ui-module-cache Sources/DetailPanel.swift Sources/DescriptionMarkdownRules.swift Sources/DescriptionMarkdown.swift Tests/EditorInteractionTests.swift -o build/EditorInteractionTests -framework SwiftUI -framework AppKit
build/EditorInteractionTests

xcrun swiftc -module-cache-path build/ui-module-cache Sources/InspectorResizeHandle.swift Tests/InspectorResizeTests.swift -o build/InspectorResizeTests -framework SwiftUI -framework AppKit
build/InspectorResizeTests
