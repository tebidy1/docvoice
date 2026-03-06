import re

file_path = r"e:\d\DOCVOICE-ORG\docvoice\lib\web_extension\screens\extension_settings_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Fix undefined 'theme' variable
content = content.replace("theme.scaffoldBackgroundColor", "Theme.of(context).scaffoldBackgroundColor")
content = content.replace("theme.cardTheme.color", "Theme.of(context).cardTheme.color")

# 2. Add 'final theme = Theme.of(context);' if I missed it? We replaced it with Theme.of(context) directly, so that's fine.

# 3. Remove 'const' before Text, TextStyle, Divider, Icon if they contain Theme.of(context)
content = re.sub(r'const\s+TextStyle\(([^)]*?Theme\.of\(context\)[^)]*?)\)', r'TextStyle(\1)', content)
# Handle multiline Text and TextStyle consts
content = re.sub(r'const\s+Text\(([\s\S]*?Theme\.of\(context\)[\s\S]*?)\)', r'Text(\1)', content)
content = re.sub(r'const\s+TextStyle\(([\s\S]*?Theme\.of\(context\)[\s\S]*?)\)', r'TextStyle(\1)', content)
content = re.sub(r'const\s+Divider\(([\s\S]*?Theme\.of\(context\)[\s\S]*?)\)', r'Divider(\1)', content)
content = re.sub(r'const\s+Icon\(([\s\S]*?Theme\.of\(context\)[\s\S]*?)\)', r'Icon(\1)', content)

# Some specific replacements for constant collections or deeper trees
# Fallback replacement for any const TextStyle or Text that still remains with Theme.of
lines = content.split('\n')
for i in range(len(lines)):
    if 'Theme.of(context)' in lines[i]:
        # remove const from the same line if it causes issues
        lines[i] = re.sub(r'const\s+Text\(', 'Text(', lines[i])
        lines[i] = re.sub(r'const\s+TextStyle\(', 'TextStyle(', lines[i])
        lines[i] = re.sub(r'const\s+Icon\(', 'Icon(', lines[i])
        lines[i] = re.sub(r'const\s+Divider\(', 'Divider(', lines[i])

# Join back
content = '\n'.join(lines)

# If 'const' is on a previous line, the multiline regex should have caught it, but let's be safe.
# Another pass for multiline const Text/TextStyle
content = re.sub(r'const\s+Text\s*\(\s*(?:"[^"]*"|''[^'']*'')\s*,\s*style:\s*(?:const\s+)?TextStyle\s*\([\s\S]*?Theme\.of\(context\)[\s\S]*?\)\s*\)', lambda m: m.group(0).replace('const Text', 'Text').replace('const TextStyle', 'TextStyle'), content)

# Replace specific known errors
content = content.replace('style: const TextStyle(color:', 'style: TextStyle(color:')
content = content.replace('style: const\n                                      TextStyle', 'style: TextStyle')
content = content.replace('style: const\n                      TextStyle', 'style: TextStyle')
content = content.replace('style: const TextStyle(fontSize:', 'style: TextStyle(fontSize:')

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
