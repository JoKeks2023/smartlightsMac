import re

pbxproj = "Govee Mac.xcodeproj/project.pbxproj"
with open(pbxproj, 'r') as f:
    content = f.read()

# Find INFOPLIST_KEY entries and add HomeKit usage description
pattern = r'(INFOPLIST_KEY_NSMainStoryboardFile = Main;)'
replacement = r'\1\n\t\t\t\tINFOPLIST_KEY_NSHomeKitUsageDescription = "Govee Mac needs access to control your HomeKit-enabled Govee lights.";'

if pattern in content:
    content = re.sub(pattern, replacement, content)
    with open(pbxproj, 'w') as f:
        f.write(content)
    print("Added HomeKit usage description to Info.plist")
else:
    print("Pattern not found, trying alternative approach")
    # Try adding to build settings
    pattern2 = r'(buildSettings = \{[^\}]*?)(ENABLE_HARDENED_RUNTIME = YES;)'
    replacement2 = r'\1INFOPLIST_KEY_NSHomeKitUsageDescription = "Govee Mac needs access to control your HomeKit-enabled Govee lights.";\n\t\t\t\t\2'
    content = re.sub(pattern2, replacement2, content)
    with open(pbxproj, 'w') as f:
        f.write(content)
    print("Added via alternative method")
