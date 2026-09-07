"""Export named day-to-day UI evidence from xcresulttool's attachment directory.

Usage: python3 scripts/export-ui-evidence.py ATTACHMENTS OUTPUT
"""
import json
from pathlib import Path
import shutil
import sys

source, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
for test in json.loads((source / 'manifest.json').read_text()):
    for attachment in test['attachments']:
        name = attachment['suggestedHumanReadableName'].split('_0_')[0]
        if name.startswith(('en-US-', 'ja-JP-')):
            shutil.copyfile(source / attachment['exportedFileName'], output / (name + '.png'))
shutil.copyfile(source / 'manifest.json', output / 'manifest.json')
