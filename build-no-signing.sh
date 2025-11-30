#!/bin/bash

echo "🚀 Building Govee Mac without code signing..."
echo ""

cd "$(dirname "$0")"

# Build without signing
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Debug \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ BUILD SUCCESSFUL!"
    echo ""
    echo "To run the app:"
    echo "  open build/Build/Products/Debug/Govee\ Mac.app"
    echo ""
    echo "Or just press ⌘R in Xcode!"
else
    echo ""
    echo "❌ Build failed. Check errors above."
fi
