"""Configure Godot's SDK paths in an ephemeral GitHub Actions runner."""
from pathlib import Path
import json,os
settings=Path.home()/'.config/godot/editor_settings-4.6.tres'
settings.parent.mkdir(parents=True,exist_ok=True)
settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    +'export/android/android_sdk_path = '+json.dumps(os.environ['ANDROID_HOME'])+'\n'
    +'export/android/java_sdk_path = '+json.dumps(os.environ['JAVA_HOME'])+'\n')
