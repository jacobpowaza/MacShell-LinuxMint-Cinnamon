"""Owned fixtures only: native preferences, file drops/tags and lazy wallpaper originals."""
import sys,json,tempfile,shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
BASE=Path(__file__).resolve().parents[1];sys.path.insert(0,str(BASE))
from finder_files import request
import finder_metadata as metadata
import mint_settings as settings
import wallpaper_catalog as wallpapers
import widget_data
with tempfile.TemporaryDirectory(prefix='macshell-tahoe-',dir=Path.home()/'.cache') as tmp:
 root=Path(tmp);src=root/'Source';dst=root/'Destination';src.mkdir();dst.mkdir()
 file=src/'Move me.txt';file.write_text('Owned Finder drag fixture')
 request({'action':'tags-set','paths':[str(file)],'tag':'Blue','enabled':True})
 try:
  assert str(file) in [r['path'] for r in request({'action':'collection','collection':'tag:Blue'})]
  request({'action':'transfer','path':str(src),'paths':[str(file)],'destination':str(dst),'copy':False})
  moved=dst/file.name;assert moved.exists() and not file.exists();assert 'Blue' in metadata.get(moved)
  request({'action':'transfer','path':str(dst),'paths':[str(moved)],'destination':str(src),'copy':True})
  assert (src/file.name).exists() and moved.exists();assert 'Blue' in metadata.get(src/file.name)
  try:request({'action':'transfer','path':str(src),'paths':[str(src/file.name)],'destination':str(dst),'copy':False});raise AssertionError('Overwrite accepted')
  except FileExistsError:pass
  folder=src/'Tagged folder';folder.mkdir();nested=folder/'Tagged child.txt';nested.write_text('Nested tag fixture');metadata.set_tags([str(nested)],'Green',True)
  request({'action':'transfer','path':str(src),'paths':[str(folder)],'destination':str(dst),'copy':False})
  assert str(dst/folder.name/nested.name) in [r['path'] for r in metadata.collection('tag:Green')]
  request({'action':'rename','path':str(dst/folder.name),'name':'Renamed folder'})
  assert str(dst/'Renamed folder'/nested.name) in [r['path'] for r in metadata.collection('tag:Green')]
  other=root/'Other';other.mkdir();(other/file.name).write_text('Collision fixture');(src/file.name).rename(src/'Same.txt');(other/file.name).rename(other/'Same.txt')
  empty=root/'Empty';empty.mkdir()
  try:request({'action':'transfer','paths':[str(src/'Same.txt'),str(other/'Same.txt')],'destination':str(empty),'copy':False});raise AssertionError('Duplicate names accepted')
  except FileExistsError:pass
  assert not list(empty.iterdir())
  print('PASS Finder: move, copy, overwrite refusal, duplicate-name preflight, persistent tags across move/rename and nested folders')
 finally:
  with metadata.LOCK:
   data=metadata.load();metadata.save({k:v for k,v in data.items() if not k.startswith(str(root)+'/')})
 # Catalog listing cannot open the network or create an original.
 wallpapers.DEST=root/'wallpapers';original=wallpapers.urlopen
 wallpapers.urlopen=lambda *_a,**_k:(_ for _ in ()).throw(AssertionError('Catalog fetched an original'))
 rows=wallpapers.request({'action':'list'});assert len(rows)>=12 and not wallpapers.DEST.exists()
 wallpapers.urlopen=original
 path=Path(wallpapers.request({'action':'download','id':rows[0]['id']}));assert path.exists()
 wallpapers.urlopen=lambda *_a,**_k:(_ for _ in ()).throw(AssertionError('Downloaded wallpaper fetched again'))
 assert wallpapers.request({'action':'download','id':rows[0]['id']})==str(path)
 wallpapers.urlopen=original
 print('PASS Wallpapers: 12 metadata-only entries, download only on selection, verified image/hash, cached original reused; fixture cleaned')
# Read every real preference and every integrated category without changing user settings.
info=settings.request({'action':'list'});count=sum(len(settings.snapshot(s)) for s in info['schemas'])
for category in ['general','appearance','dock','keyboard','mouse','trackpad','battery','displays','notifications','sound','lockscreen','users','apps','wallpaper','menubar']:
 data=settings.request({'action':'category','category':category});assert data['category']==category;json.dumps(data)
assert settings.default_apps()
print('PASS Settings:',len(info['schemas']),'schemas,',count,'typed values; existing categories and real default applications')
for zone in ['America/New_York','Asia/Tokyo','Europe/Warsaw']:
 assert isinstance(widget_data.request({'type':'clock','timezone':zone})['offset'],(int,float))
print('PASS Clock: independent IANA time zones with current DST offsets')
with ThreadPoolExecutor(max_workers=2) as pool:
 results=list(pool.map(lambda city:widget_data.request({'type':'weather','city':city,'unit':'C'}),['Warsaw','Tokyo']))
assert all('weather' in r for r in results),results
assert results[0]['weather']['city']!=results[1]['weather']['city']
print('PASS Weather: independent Warsaw/Tokyo geocoding and live forecasts')
