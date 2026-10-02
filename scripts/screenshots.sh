#!/bin/bash
# Re-renders the README screenshots in docs/screenshots from the app's real SwiftUI views.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -q
"$(swift build --show-bin-path)/Move" --screenshots docs/screenshots
