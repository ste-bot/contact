#!/bin/zsh
# Builds Contact and installs it in /Applications, replacing any earlier copy.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
osascript -e 'tell application id "com.stevenchen.contact" to quit' 2>/dev/null || true
rm -rf /Applications/Contact.app
ditto build/Contact.app /Applications/Contact.app
# Nudge Finder and the Dock to pick up the new icon.
touch /Applications/Contact.app
echo "Installed /Applications/Contact.app"
