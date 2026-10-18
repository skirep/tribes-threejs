"""Validate aapt xmltree output, including Godot 4.6's launcher alias.

Old aapt badging omits launchable-activity for activity-alias entries.
"""
from pathlib import Path
import re
import sys


def validate(text):
    root = {"tag": "root", "attrs": {}, "children": []}
    stack = [(-1, root)]
    for line in text.splitlines():
        indent = len(line) - len(line.lstrip())
        if line.lstrip().startswith("E: "):
            while stack[-1][0] >= indent:
                stack.pop()
            node = {"tag": line.strip().split()[1], "attrs": {}, "children": []}
            stack[-1][1]["children"].append(node)
            stack.append((indent, node))
        elif line.lstrip().startswith("A: "):
            match = re.match(r'A: ([\w:]+)(?:\([^)]*\))?=(.*)', line.strip())
            if match:
                value = match[2].split(' (Raw:')[0].strip('"')
                stack[-1][1]["attrs"][match[1]] = value
    manifest = root["children"][0]
    assert manifest["attrs"]["package"] == "cat.skirep.tribes360"
    app = next(n for n in manifest["children"] if n["tag"] == "application")
    activities = {n["attrs"].get("android:name") for n in app["children"] if n["tag"] == "activity"}
    for node in app["children"]:
        if node["tag"] not in ("activity", "activity-alias"):
            continue
        for intent in node["children"]:
            if intent["tag"] != "intent-filter":
                continue
            names = {n["attrs"].get("android:name") for n in intent["children"]}
            if {"android.intent.action.MAIN", "android.intent.category.LAUNCHER"} <= names:
                assert node["attrs"].get("android:exported") == "(type 0x12)0xffffffff"
                if node["tag"] == "activity-alias":
                    assert node["attrs"].get("android:targetActivity") in activities
                assert 'oculus.intent.category.VR' not in text
                assert 'android.intent.category.HOME' not in text
                return
    raise AssertionError("No exported MAIN/LAUNCHER activity or valid launcher alias")


if __name__ == "__main__":
    validate(Path(sys.argv[1]).read_text())
    print("PHONE_MANIFEST_OK: exported launcher, normal Android package, no VR/home category")
