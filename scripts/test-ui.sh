#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ui-module-cache
# This harness has no Store and cannot read or write character, compendium, or activity files.
xcrun swiftc -module-cache-path build/ui-module-cache Sources/DetailPanel.swift Sources/DescriptionMarkdownRules.swift Sources/DescriptionMarkdown.swift Tests/EditorInteractionTests.swift -o build/EditorInteractionTests -framework SwiftUI -framework AppKit
build/EditorInteractionTests

xcrun swiftc -module-cache-path build/ui-module-cache Sources/InspectorResizeHandle.swift Tests/InspectorResizeTests.swift -o build/InspectorResizeTests -framework SwiftUI -framework AppKit
build/InspectorResizeTests

# Toolbar/filter geometry checks use no Store or live data location.
xcrun swiftc -module-cache-path build/ui-module-cache Sources/PageToolbar.swift Tests/PageLayoutTests.swift -o build/PageLayoutTests -framework SwiftUI -framework AppKit
build/PageLayoutTests

# Folding preferences use a unique temporary defaults suite and no Store.
xcrun swiftc -module-cache-path build/ui-module-cache Sources/SheetCard.swift Tests/SheetCardTests.swift -o build/SheetCardTests -framework SwiftUI -framework AppKit
build/SheetCardTests

# Equal row heights/footer geometry at responsive column counts; no Store or live data.
xcrun swiftc -module-cache-path build/ui-module-cache Sources/EqualHeightGridLayout.swift Tests/EqualHeightGridTests.swift -o build/EqualHeightGridTests -framework SwiftUI -framework AppKit
build/EqualHeightGridTests
