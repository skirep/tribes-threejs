"""Regression checks for complete, assembled original character meshes."""
import json,math,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def bounds(m):
 v=m['vertices']
 return [(min(v[i::3]),max(v[i::3])) for i in range(3)]
def gap(a,b):
 return math.sqrt(sum(max(0,x[0]-y[1],y[0]-x[1])**2 for x,y in zip(bounds(a),bounds(b))))
class Models(unittest.TestCase):
 def test_all_exported_meshes_are_present(self):
  for path in (ROOT/'assets').glob('*.json'):
   data=json.loads(path.read_text())
   with self.subTest(scene=path.name):self.assertEqual(len(data['meshes']),data['expectedMeshCount'])
 def test_character_parts_connect(self):
  data=json.loads((ROOT/'assets/creds.json').read_text());m={o['name']:o for o in data['meshes']}
  # Distances in the source's world units, before the display scale is applied.
  # The original rear lower-leg names have L/R exchanged.
  for a,b in [('KID HEAD','KID NECK'),('KID NECK','KID TORSO'),('KID TORSO','KID BOTM'),('GRL FACE','GRLNECK'),('GRL FACE','GLASSES'),('G LEG Frt L Up','G LEG Frt L Dwn'),('G LEG Frt R Up','G LEG Frt R Dwn'),('G LEG Rr L Up','G LEG Rr R Dwn'),('G LEG Rr R Up','G LEG Rr L Dwn')]:
   with self.subTest(joint=(a,b)):self.assertLess(gap(m[a],m[b]),1.0)
 def test_indices_and_vertices_are_valid(self):
  for path in (ROOT/'assets').glob('*.json'):
   for m in json.loads(path.read_text())['meshes']:
    self.assertTrue(all(math.isfinite(v) for v in m['vertices']))
    self.assertTrue(all(m['faces'][i]<len(m['vertices'])//3 for i in range(len(m['faces'])) if i%4<3))
if __name__=='__main__':unittest.main()
