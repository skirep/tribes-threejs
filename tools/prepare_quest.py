"""Stage the corrected shared assets for the native Quest project."""
from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parents[1]
target = ROOT / 'quest' / 'assets'
target.mkdir(parents=True, exist_ok=True)
for source in (ROOT / 'assets').iterdir():
    if source.suffix.lower() in {'.jpg', '.png', '.mp3', '.json'}:
        shutil.copy2(source, target / source.name)
print('Staged shared textures, corrected models and music:', target)
