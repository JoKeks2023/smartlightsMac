#!/bin/bash

echo "🔍 Verifying Govee Mac Build Configuration..."
echo ""

cd "$(dirname "$0")"

echo "✓ Checking if GoveeModels.swift exists..."
if [ -f "Govee Mac/GoveeModels.swift" ]; then
    echo "  ✅ GoveeModels.swift found"
else
    echo "  ❌ GoveeModels.swift NOT FOUND!"
    exit 1
fi

echo ""
echo "✓ Checking if GoveeModels.swift is in Compile Sources..."
if grep -q "209313B605604EAF8C30C5D6.*GoveeModels.swift in Sources" "Govee Mac.xcodeproj/project.pbxproj"; then
    echo "  ✅ GoveeModels.swift IS in Compile Sources"
else
    echo "  ❌ GoveeModels.swift NOT in Compile Sources!"
    exit 1
fi

echo ""
echo "✓ Checking for duplicate GoveeModels.swift references..."
COUNT=$(grep -c "GoveeModels.swift" "Govee Mac.xcodeproj/project.pbxproj")
if [ "$COUNT" -eq 3 ]; then
    echo "  ✅ Exactly 3 references (correct: PBXBuildFile, PBXFileReference, PBXGroup)"
elif [ "$COUNT" -gt 3 ]; then
    echo "  ⚠️  $COUNT references found (expected 3) - may have duplicates"
else
    echo "  ❌ Only $COUNT references found (expected 3)"
fi

echo ""
echo "✓ Checking Swift syntax in key files..."
swift -frontend -parse "Govee Mac/GoveeModels.swift" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  ✅ GoveeModels.swift syntax OK"
else
    echo "  ❌ GoveeModels.swift has syntax errors!"
    exit 1
fi

echo ""
echo "✓ Checking for required types in GoveeModels.swift..."
TYPES=("SettingsStore" "DeviceStore" "GoveeController")
for TYPE in "${TYPES[@]}"; do
    if grep -q "class $TYPE" "Govee Mac/GoveeModels.swift"; then
        echo "  ✅ $TYPE defined"
    else
        echo "  ❌ $TYPE NOT FOUND!"
        exit 1
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ALL CHECKS PASSED!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your project is correctly configured."
echo "You can now build in Xcode with ⌘B"
echo ""
echo "Or build from terminal:"
echo "  xcodebuild -project \"Govee Mac.xcodeproj\" \\"
echo "    -scheme \"Govee Mac\" \\"
echo "    -configuration Debug \\"
echo "    CODE_SIGN_IDENTITY=\"\" \\"
echo "    CODE_SIGNING_REQUIRED=NO \\"
echo "    CODE_SIGNING_ALLOWED=NO \\"
echo "    build"
echo ""
