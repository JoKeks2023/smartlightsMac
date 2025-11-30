#!/bin/bash

# Govee Mac - Open Source Readiness Check
# Verifies project is ready for GitHub

echo "🔍 Checking Govee Mac Open Source Readiness..."
echo ""

cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅${NC} $1"
        ((PASS++))
    else
        echo -e "${RED}❌${NC} $1 - MISSING"
        ((FAIL++))
    fi
}

check_optional() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅${NC} $1"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠️${NC}  $1 - Optional (not critical)"
        ((WARN++))
    fi
}

# Essential Files
echo "📋 Essential Files:"
check_file "README.md"
check_file "LICENSE"
check_file ".gitignore"
check_file "CONTRIBUTING.md"
echo ""

# Documentation
echo "📚 Documentation:"
check_file "FREE_APPLE_ID_GUIDE.md"
check_file "FEATURES.md"
check_file "START_HERE.md"
echo ""

# Project Files
echo "🏗️  Project Structure:"
check_file "Govee Mac.xcodeproj/project.pbxproj"
check_file "Govee Mac/GoveeModels.swift"
check_file "Govee Mac/Govee_MacApp.swift"
check_file "Govee Mac/ContentView.swift"
check_file "Govee Mac/MenuBarController.swift"
echo ""

# CI/CD
echo "⚙️  Automation:"
check_file ".github/workflows/ci.yml"
echo ""

# Optional
echo "🎨 Optional (enhance later):"
check_optional "Screenshots/main-window.png"
check_optional "CHANGELOG.md"
echo ""

# Check for secrets
echo "🔒 Security Check:"
if grep -r "sk-" "Govee Mac/" --include="*.swift" 2>/dev/null | grep -v "example" | grep -q .; then
    echo -e "${RED}❌${NC} Found potential API keys in code!"
    ((FAIL++))
else
    echo -e "${GREEN}✅${NC} No API keys found in code"
    ((PASS++))
fi

if [ -f ".gitignore" ] && grep -q "*.key" .gitignore; then
    echo -e "${GREEN}✅${NC} .gitignore protects API keys"
    ((PASS++))
else
    echo -e "${RED}❌${NC} .gitignore doesn't protect API keys"
    ((FAIL++))
fi
echo ""

# Build Test (optional - takes time)
echo "🔨 Build Test (optional - takes ~1 minute):"
read -p "Test build without signing? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Building..."
    if xcodebuild -project "Govee Mac.xcodeproj" \
        -scheme "Govee Mac" \
        -configuration Debug \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        build > /dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} Build successful!"
        ((PASS++))
    else
        echo -e "${RED}❌${NC} Build failed - check for errors"
        ((FAIL++))
    fi
else
    echo -e "${YELLOW}⚠️${NC}  Skipped build test"
    ((WARN++))
fi
echo ""

# Git Status
echo "📦 Git Status:"
if [ -d ".git" ]; then
    echo -e "${YELLOW}⚠️${NC}  Git already initialized"
    ((WARN++))
else
    echo -e "${GREEN}✅${NC} Ready to initialize Git (run: git init)"
    ((PASS++))
fi
echo ""

# Results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Results:"
echo -e "${GREEN}✅ Passed: $PASS${NC}"
if [ $WARN -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warnings: $WARN${NC}"
fi
if [ $FAIL -gt 0 ]; then
    echo -e "${RED}❌ Failed: $FAIL${NC}"
fi
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS! Your project is ready for GitHub!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test build in Xcode with your Apple ID"
    echo "2. git init"
    echo "3. git add ."
    echo "4. git commit -m 'Initial commit'"
    echo "5. Create repo on GitHub"
    echo "6. git remote add origin YOUR_REPO_URL"
    echo "7. git push -u origin main"
    echo ""
    echo "See START_HERE.md for detailed instructions!"
else
    echo -e "${RED}⚠️  Some checks failed. Review the issues above.${NC}"
    echo "See documentation files for help."
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
