#!/bin/sh
# XcodeGen only supports `storeKitConfiguration` on Run/Target schemes,
# not on the Test action. SKTestSession needs the scheme reference to
# sandbox the app's StoreKit environment, so patch the generated scheme
# right after `xcodegen` (postGenCommand in project.yml).
set -eu

SCHEME="$(cd "$(dirname "$0")/.." && pwd)/Karta.xcodeproj/xcshareddata/xcschemes/Karta.xcscheme"
STOREKIT="../../Karta.storekit"

if grep -q '<StoreKitConfigurationFileReference' "$SCHEME" && \
   sed -n '/<TestAction/,/<\/TestAction>/p' "$SCHEME" | grep -q 'StoreKitConfigurationFileReference'; then
    exit 0
fi

python3 - "$SCHEME" "$STOREKIT" <<'PY'
import sys

path, storekit = sys.argv[1], sys.argv[2]
scheme = open(path).read()

node = (
    "      <StoreKitConfigurationFileReference\n"
    f"         identifier = \"{storekit}\">\n"
    "      </StoreKitConfigurationFileReference>\n"
)

close = "   </TestAction>"
assert close in scheme, "no </TestAction> in Karta.xcscheme"
scheme = scheme.replace(close, node + close, 1)

open(path, "w").write(scheme)
PY
