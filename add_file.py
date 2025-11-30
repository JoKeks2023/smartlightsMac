import sys, uuid

pbxproj = "Govee Mac.xcodeproj/project.pbxproj"
with open(pbxproj, 'r') as f:
    content = f.read()

file_ref_id = str(uuid.uuid4()).replace('-', '')[:24].upper()
build_file_id = str(uuid.uuid4()).replace('-', '')[:24].upper()

# Add file reference
file_ref = f'\t\t{file_ref_id} /* GoveeModels.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = GoveeModels.swift; sourceTree = "<group>"; }};\n'
insert_pos = content.find('5B80D9BE2EDCB128000DBD74 /* ContentView.swift */')
if insert_pos > 0:
    end_line = content.find('\n', insert_pos) + 1
    content = content[:end_line] + file_ref + content[end_line:]

# Add build file
build_file = f'\t\t{build_file_id} /* GoveeModels.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* GoveeModels.swift */; }};\n'
insert_pos = content.find('5B80D9BF2EDCB128000DBD74 /* ContentView.swift in Sources */')
if insert_pos > 0:
    end_line = content.find('\n', insert_pos) + 1
    content = content[:end_line] + build_file + content[end_line:]

# Add to children array (Govee Mac group)
children_marker = '5B80D9BE2EDCB128000DBD74 /* ContentView.swift */,'
insert_pos = content.find(children_marker)
if insert_pos > 0:
    end_line = content.find('\n', insert_pos) + 1
    child_entry = f'\t\t\t\t{file_ref_id} /* GoveeModels.swift */,\n'
    content = content[:end_line] + child_entry + content[end_line:]

# Add to PBXSourcesBuildPhase
sources_marker = '5B80D9BF2EDCB128000DBD74 /* ContentView.swift in Sources */,'
insert_pos = content.find(sources_marker)
if insert_pos > 0:
    end_line = content.find('\n', insert_pos) + 1
    source_entry = f'\t\t\t\t{build_file_id} /* GoveeModels.swift in Sources */,\n'
    content = content[:end_line] + source_entry + content[end_line:]

with open(pbxproj, 'w') as f:
    f.write(content)

print(f"Added GoveeModels.swift with IDs {file_ref_id} and {build_file_id}")
