import re
import sys

pbxproj_path = "Govee Mac.xcodeproj/project.pbxproj"

print("Disabling code signing in Xcode project...")

with open(pbxproj_path, 'r') as f:
    content = f.read()

# Disable all code signing
content = re.sub(r'CODE_SIGN_IDENTITY = ".*?";', 'CODE_SIGN_IDENTITY = "";', content)
content = re.sub(r'CODE_SIGN_STYLE = .*?;', 'CODE_SIGN_STYLE = Manual;', content)  
content = re.sub(r'DEVELOPMENT_TEAM = .*?;', 'DEVELOPMENT_TEAM = "";', content)
content = re.sub(r'PROVISIONING_PROFILE_SPECIFIER = .*?;', 'PROVISIONING_PROFILE_SPECIFIER = "";', content)

# Add CODE_SIGNING_REQUIRED = NO to all buildSettings
content = re.sub(
    r'(buildSettings = \{)',
    r'\1\n\t\t\t\tCODE_SIGNING_REQUIRED = NO;\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;',
    content
)

with open(pbxproj_path, 'w') as f:
    f.write(content)

print("✅ Code signing disabled!")
print("ℹ️  You can now build in Xcode without an Apple ID")
