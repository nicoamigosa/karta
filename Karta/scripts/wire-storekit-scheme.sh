#!/bin/sh
# XcodeGen only supports `storeKitConfiguration` on Run/Target schemes,
# not on the Test action. SKTestSession needs the scheme reference to
# sandbox the app's StoreKit environment, so patch the generated scheme
# right after `xcodegen` (postGenCommand in project.yml).
#
# XcodeGen regenerates the project each run, so the checked-in test
# plans' target identifier is patched to the fresh KartaTests UUID.
set -eu

KARTA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="$KARTA_DIR/Karta.xcodeproj/xcshareddata/xcschemes/Karta.xcscheme"
PBXPROJ="$KARTA_DIR/Karta.xcodeproj/project.pbxproj"
STOREKIT="../../Karta.storekit"

python3 - "$SCHEME" "$PBXPROJ" "$STOREKIT" "$KARTA_DIR" <<'PY'
import re
import sys

scheme_path, pbxproj_path, storekit, karta_dir = sys.argv[1:5]
scheme = open(scheme_path).read()
pbxproj = open(pbxproj_path).read()

# The native target UUIDs XcodeGen just generated, by target name.
uuids = {name: uuid for uuid, name in re.findall(
    r'([A-F0-9]{24}) /\* (\w+) \*/ = \{\s*isa = PBXNativeTarget',
    pbxproj,
)}
for name in ("Karta", "KartaTests", "KartaStoreKitTests"):
    assert name in uuids, f"{name} target not found in project.pbxproj"

# Keep the checked-in test plans pointing at those UUIDs.
for plan in ("KartaTests.xctestplan", "KartaStoreKit.xctestplan"):
    path = f"{karta_dir}/{plan}"
    content = open(path).read()
    patched = re.sub(
        r'"identifier" : "[A-F0-9]{24}",(\s*\n\s*"name" : "(\w+)")',
        lambda m: f'"identifier" : "{uuids[m.group(2)]}",{m.group(1)}',
        content,
    )
    if patched != content:
        open(path, "w").write(patched)

changed = False

test_action = scheme[scheme.index("<TestAction"):scheme.index("</TestAction>")]
if "StoreKitConfigurationFileReference" not in test_action:
    node = (
        "      <StoreKitConfigurationFileReference\n"
        f"         identifier = \"{storekit}\">\n"
        "      </StoreKitConfigurationFileReference>\n"
    )
    close = "   </TestAction>"
    assert close in scheme, "no </TestAction> in Karta.xcscheme"
    scheme = scheme.replace(close, node + close, 1)
    changed = True

if changed:
    open(scheme_path, "w").write(scheme)
PY
