"""Decode a HEIC's primary still through the system libheif, for Cinnamon."""
import ctypes as C
from PIL import Image
class Error(C.Structure):_fields_=[('code',C.c_int),('subcode',C.c_int),('message',C.c_char_p)]
def convert(source,destination):
    lib=C.CDLL('libheif.so.1');ptr=C.c_void_p
    def bind(name,args,result):
        f=getattr(lib,name);f.argtypes=args;f.restype=result;return f
    alloc=bind('heif_context_alloc',[],ptr);free=bind('heif_context_free',[ptr],None)
    read=bind('heif_context_read_from_file',[ptr,C.c_char_p,ptr],Error)
    primary=bind('heif_context_get_primary_image_handle',[ptr,C.POINTER(ptr)],Error)
    release_handle=bind('heif_image_handle_release',[ptr],None)
    width=bind('heif_image_handle_get_width',[ptr],C.c_int);height=bind('heif_image_handle_get_height',[ptr],C.c_int)
    decode=bind('heif_decode_image',[ptr,C.POINTER(ptr),C.c_int,C.c_int,ptr],Error)
    release_image=bind('heif_image_release',[ptr],None)
    plane=bind('heif_image_get_plane_readonly',[ptr,C.c_int,C.POINTER(C.c_int)],ptr)
    def check(e):
        if e.code:raise ValueError((e.message or b'HEIC decode failed').decode(errors='replace'))
    ctx=alloc();handle=ptr();image=ptr()
    if not ctx:raise MemoryError('Cannot open HEIC decoder')
    try:
        check(read(ctx,str(source).encode(),None));check(primary(ctx,C.byref(handle)))
        w,h=width(handle),height(handle)
        if w<=0 or h<=0 or w*h>100_000_000:raise ValueError('Unsupported HEIC dimensions')
        check(decode(handle,C.byref(image),1,10,None)) # RGB / interleaved RGB
        stride=C.c_int();data=plane(image,10,C.byref(stride))
        if not data or stride.value<w*3:raise ValueError('HEIC has no RGB image')
        Image.frombytes('RGB',(w,h),C.string_at(data,stride.value*h),'raw','RGB',stride.value).save(destination,format='JPEG',quality=95)
    finally:
        if image:release_image(image)
        if handle:release_handle(handle)
        free(ctx)
