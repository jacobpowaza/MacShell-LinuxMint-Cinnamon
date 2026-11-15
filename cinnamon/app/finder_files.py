"""Host filesystem operations for the MacShell Finder adaptation.

Browsing is a native, lazy Qt folder model. Mutations go through GIO/standard
filesystem calls and never overwrite existing destinations silently.
"""
import os,shutil,subprocess,mimetypes,configparser
from pathlib import Path
from urllib.parse import urlparse,unquote
from gi.repository import Gio

def path_of(value):
 value=str(value)
 return Path(unquote(urlparse(value).path) if value.startswith('file:') else value).expanduser().absolute()
def child(parent,name):
 if not name or name in ['.','..'] or '/' in name or '\x00' in name:raise ValueError('Enter a name without slashes.')
 return parent/name

def request(arg):
 action=arg['action']
 if action in ['trash-state','empty-trash','delete-forever']:
  import trash_service
  if action=='trash-state':return trash_service.status()
  return trash_service.delete(arg.get('paths',[]) if action=='delete-forever' else None)
 if action in ['locations','collection','tags-get','tags-set','favorites','favorites-add','favorites-remove']:
  from finder_metadata import request as metadata_request
  return metadata_request(arg)
 selection=arg.get('selection','clipboard')
 if selection not in ['clipboard','secondary','primary']:raise ValueError('Invalid clipboard selection.')
 path=path_of(arg.get('path',str(Path.home())))
 if action=='applications':
  return [{'name':a.get_display_name(),'path':a.get_id(),'icon':a.get_icon().to_string() if a.get_icon() else 'application-x-executable','url':Path(a.get_filename()).as_uri(),'directory':False,'application':True,'size':0,'modified':''} for a in sorted(Gio.AppInfo.get_all(),key=lambda a:a.get_display_name().casefold()) if a.should_show() and a.get_id() and hasattr(a,'get_filename') and a.get_filename()]
 if action=='info':
  path=path.resolve(strict=True)
  if not path.is_dir():raise NotADirectoryError('This location is not a folder.')
  disk=shutil.disk_usage(path)
  return {'path':str(path),'url':path.as_uri(),'free':disk.free,'total':disk.total}
 if action=='transfer':
  from finder_metadata import relocate
  target=path_of(arg['destination']).resolve(strict=True)
  if not target.is_dir():raise NotADirectoryError('Drop onto a folder.')
  sources=[path_of(v) for v in arg['paths']];copy=bool(arg.get('copy',False));done=[]
  # Validate the entire drop before changing anything.
  names=set()
  for source in sources:
   destination=target/source.name
   if not source.exists() and not source.is_symlink():raise FileNotFoundError(source.name)
   if source.name in names:raise FileExistsError('Two dragged items have the same name. Move them separately.')
   names.add(source.name)
   if source.absolute()==destination.absolute():continue
   if destination.exists() or destination.is_symlink():raise FileExistsError('“'+source.name+'” already exists here. Nothing will be overwritten.')
   if source.is_dir() and not source.is_symlink() and source.resolve() in destination.resolve().parents:raise ValueError('A folder cannot be moved inside itself.')
  for source in sources:
   destination=target/source.name
   if source.absolute()==destination.absolute():continue
   if copy:
    if source.is_dir() and not source.is_symlink():shutil.copytree(source,destination,symlinks=True)
    else:shutil.copy2(source,destination,follow_symlinks=False)
   else:shutil.move(str(source),str(destination))
   relocate(source,destination,copy=copy);done.append(str(destination))
  return {'paths':done,'copied':copy}
 if action=='stat':
  import stat,pwd,grp
  info=path.stat()
  return {'name':path.name,'path':str(path),'kind':'Folder' if path.is_dir() else mimetypes.guess_type(path.name)[0] or 'Document','size':info.st_size,'modified':info.st_mtime,'created':info.st_ctime,'owner':pwd.getpwuid(info.st_uid).pw_name,'group':grp.getgrgid(info.st_gid).gr_name,'permissions':stat.filemode(info.st_mode)}
 if action=='mkdir':
  destination=child(path,str(arg['name']));destination.mkdir();return {'path':str(destination)}
 if action=='rename':
  destination=child(path.parent,str(arg['name']))
  if destination!=path and (destination.exists() or destination.is_symlink()):raise FileExistsError('An item with this name already exists.')
  path.rename(destination)
  from finder_metadata import relocate
  relocate(path,destination)
  return {'path':str(destination)}
 if action=='trash':
  done=[]
  for value in arg['paths']:
   item=path_of(value)
   if not Gio.File.new_for_path(str(item)).trash(None):raise OSError('Could not move '+item.name+' to Trash.')
   done.append(str(item))
  return {'paths':done}
 if action=='restore':
  from trash_service import root as trash_root
  restored=[];trash=trash_root()
  for value in arg['paths']:
   source=path_of(value)
   if source.parent!=trash/'files':raise ValueError('Select an item in the home Trash to restore.')
   info=trash/'info'/(source.name+'.trashinfo');metadata=configparser.ConfigParser(interpolation=None);metadata.read(info)
   destination=Path(unquote(metadata['Trash Info']['Path']))
   if destination.exists() or destination.is_symlink():raise FileExistsError('The original location already contains “'+destination.name+'”.')
   destination.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(source),str(destination));info.unlink();restored.append(str(destination))
  return {'paths':restored}
 if action=='clipboard':
  values=[path_of(value).as_uri() for value in arg['paths']]
  content=('cut' if arg.get('cut') else 'copy')+'\n'+'\n'.join(values)
  process=subprocess.Popen(['xclip','-selection',selection,'-t','x-special/gnome-copied-files'],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  process.communicate(content.encode(),timeout=3)
  if process.returncode:raise OSError('The clipboard could not be updated.')
  return {'count':len(values),'cut':bool(arg.get('cut'))}
 if action=='paste':
  cut=False
  result=subprocess.run(['xclip','-selection',selection,'-o','-t','x-special/gnome-copied-files'],capture_output=True,text=True,timeout=3)
  if result.returncode:
   result=subprocess.run(['xclip','-selection',selection,'-o','-t','text/uri-list'],capture_output=True,text=True,timeout=3)
   rows=result.stdout.splitlines()
  else:
   rows=result.stdout.splitlines();cut=bool(rows and rows.pop(0)=='cut')
  sources=[path_of(uri) for uri in rows if uri.startswith('file:')]
  if not sources:raise ValueError('The clipboard does not contain files to paste.')
  done=[]
  for source in sources:
   destination=path/source.name
   if destination.exists() or destination.is_symlink():raise FileExistsError('“'+source.name+'” already exists here. Nothing will be overwritten.')
   if source.is_dir() and not source.is_symlink() and (source.resolve()==destination.resolve() or source.resolve() in destination.resolve().parents):raise ValueError('A folder cannot be copied inside itself.')
   if cut:shutil.move(str(source),str(destination))
   elif source.is_dir() and not source.is_symlink():shutil.copytree(source,destination,symlinks=True)
   else:shutil.copy2(source,destination,follow_symlinks=False)
   done.append(str(destination))
  return {'paths':done,'cut':cut}
 if action=='preview':
  stat=path.stat();mime=mimetypes.guess_type(path.name)[0] or 'application/octet-stream';text=''
  if mime.startswith('text/') or path.suffix.lower() in ['.md','.json','.qml','.py','.js','.css','.csv','.sh','.toml','.yaml','.yml']:
   with path.open('r',errors='replace') as stream:text=stream.read(65536)
  return {'path':str(path),'url':path.as_uri(),'name':path.name,'size':stat.st_size,'mime':mime,'text':text,'modified':stat.st_mtime}
 raise ValueError('Unknown Finder operation.')
