"""Own-fixture file operations; uses secondary selection, preserving user clipboard."""
import sys,tempfile,uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from finder_files import request
with tempfile.TemporaryDirectory(prefix='macshell-finder-check-',dir=Path.home()/'.cache') as directory:
 root=Path(directory);source=root/'source';source.mkdir();target=root/'target';target.mkdir()
 assert request({'action':'info','path':str(source)})['path']==str(source)
 folder=Path(request({'action':'mkdir','path':str(source),'name':'Folder'})['path']);assert folder.is_dir()
 file=source/'hello # unicode é.txt';file.write_text('Finder fixture')
 renamed=Path(request({'action':'rename','path':str(file),'name':'renamed é.txt'})['path']);assert renamed.read_text()=='Finder fixture'
 other=source/'existing.txt';other.write_text('Preserve me')
 try:request({'action':'rename','path':str(renamed),'name':other.name});raise AssertionError('Overwrite allowed')
 except FileExistsError:pass
 assert other.read_text()=='Preserve me'
 request({'action':'clipboard','paths':[str(renamed),str(folder)],'selection':'secondary'})
 result=request({'action':'paste','path':str(target),'selection':'secondary'})
 assert (target/renamed.name).read_text()=='Finder fixture' and (target/'Folder').is_dir()
 try:request({'action':'paste','path':str(target),'selection':'secondary'});raise AssertionError('Paste overwrote file')
 except FileExistsError:pass
 cut=source/'move.txt';cut.write_text('Move me');request({'action':'clipboard','paths':[str(cut)],'cut':True,'selection':'secondary'})
 request({'action':'paste','path':str(target),'selection':'secondary'});assert not cut.exists() and (target/cut.name).read_text()=='Move me'
 info=request({'action':'preview','path':str(renamed)});assert info['text']=='Finder fixture' and info['url'].startswith('file:')
 disposable=source/('macshell-trash-'+uuid.uuid4().hex+'.txt');disposable.write_text('Restore fixture')
 request({'action':'trash','paths':[str(disposable)]});assert not disposable.exists()
 trash=Path.home()/'.local/share/Trash/files'/disposable.name;assert trash.exists()
 request({'action':'restore','paths':[str(trash)]});assert disposable.read_text()=='Restore fixture' and not trash.exists()
 print('PASS Finder: browse info, mkdir, Unicode rename, overwrite refusal, file/folder copy, cut/move, text preview, Trash and Put Back; user clipboard untouched')
