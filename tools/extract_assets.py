"""Extract public original data from TRIBES.TP7 (final DOS release).
Usage: python tools/extract_assets.py /path/to/TRIBES.TP7
Only uncompressed assets are decoded; no original executable is run.
"""
from pathlib import Path
import sys,struct,re,json
src=Path(sys.argv[1]).read_bytes();out=Path(__file__).resolve().parents[1]/'assets';out.mkdir(exist_ok=True)
p=0;scenes={}
while p<len(src)-24:
 u,c,n,d,s,end=struct.unpack_from('<6I',src,p);name=src[p+25:p+24+n].decode('ascii').lower();flag=src[p+24];data=src[d:d+c]
 if flag==106:(out/name.replace('.png','.jpg')).write_bytes(data)
 if flag==112 and data.startswith(b'\x89PNG'):(out/name).write_bytes(data)
 if flag==48 and name.endswith('.exp'):scenes[name]=data
 if flag==48 and name.endswith('.unr'):(out/name).write_bytes(data)
 p=end
for name,b in scenes.items():
 nm=struct.unpack_from('<I',b,24)[0];mats=[]
 for i in range(nm):
  q=32+i*94;mn=b[q:q+16].split(b'\0')[0].decode('ascii');tex=b[q+16:q+56].split(b'\0')[0].decode('ascii').lower();color=struct.unpack_from('<3f',b,q+67)
  if tex and not (out/tex).exists() and (out/tex.replace('.png','.jpg')).exists():tex=tex.replace('.png','.jpg')
  mats.append(dict(name=mn,texture=tex,color=color))
 meshes=[]
 for q in range(32+nm*94,len(b)-112):
  raw=b[q:q+16]
  if not re.fullmatch(rb'[A-Za-z][ -~]{2,15}\x00*',raw):continue
  nv,nt,nf=struct.unpack_from('<3I',b,q+16);f=q+112+nv*12+nt*8
  if not(2<nv<20000 and nt<20000 and 1<nf<30000 and f+nf*16<len(b)):continue
  # UEXP vertices include the object pivot in world space. Remove the
  # pivot transformed by the object's basis; the vertices already include
  # world translation, so applying the whole matrix again would double it.
  basis=struct.unpack_from('<9f',b,q+52)
  pivot=struct.unpack_from('<3f',b,q+100)
  offset=[sum(basis[axis+3*j]*pivot[j] for j in range(3)) for axis in range(3)]
  raw_vertices=struct.unpack_from('<'+str(nv*3)+'f',b,q+112)
  v=[value-offset[i%3] for i,value in enumerate(raw_vertices)]
  uv=struct.unpack_from('<'+str(nt*2)+'f',b,q+112+nv*12);faces=struct.unpack_from('<'+str(nf*4)+'I',b,f)
  if any(faces[i*4+j]>=nv for i in range(nf) for j in range(3)):continue
  if any(faces[i*4+3]>=nm for i in range(nf)):continue
  tf=[]
  if nt and f+nf*28<=len(b):
   tf=list(struct.unpack_from('<'+str(nf*3)+'I',b,f+nf*16))
   if any(i>=nt for i in tf):tf=[]
  meshes.append(dict(name=raw.split(b'\0')[0].decode('ascii').strip(),vertices=list(v),uv=list(uv),faces=list(faces),uvfaces=tf,pivot=list(pivot),pivotWorldOffset=offset))
 target=out/name.replace('.exp','.json');target.write_text(json.dumps(dict(expectedMeshCount=struct.unpack_from('<I',b,4)[0],materials=mats,meshes=meshes),separators=(',',':')));print(name,len(mats),len(meshes))
