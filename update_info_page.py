import re

with open('lib/pages/info_page.dart', 'r') as f:
    content = f.read()

# Replace StatelessWidget with StatefulWidget
content = content.replace('class InfoPage extends StatelessWidget {', '''class InfoPage extends StatefulWidget {''')

# Insert state class definition
state_class = """
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
"""

content = content.replace('  @override\n  Widget build(BuildContext context) {', state_class + '  @override\n  Widget build(BuildContext context) {')

# Add missing imports
if "import 'dart:convert';" not in content:
    content = content.replace("import 'dart:io';", "import 'dart:io';\nimport 'dart:convert';")

# Replace properties with widget.
props = ['isConnected', 'branchName', 'projectPath', 'changedFiles', 'recentCommits']
for prop in props:
    content = re.sub(r'(?<!final )(?<!this\.)\b' + prop + r'\b', f'widget.{prop}', content)

# Fix double widget.
content = content.replace('widget.widget.', 'widget.')

with open('lib/pages/info_page.dart', 'w') as f:
    f.write(content)

