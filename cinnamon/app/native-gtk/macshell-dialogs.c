/* GTK3 module: restyle the real message dialog, preserving responses and defaults.
 * ABI declarations use only GTK3's stable public pointer/integer APIs; no private
 * widget structs or application hooks. GTK development headers are not required.
 */
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
typedef void *Obj;
typedef unsigned long Type;
typedef unsigned int UInt;
typedef struct List { Obj data; struct List *next,*prev; } List;
extern Type gtk_widget_get_type(void),gtk_message_dialog_get_type(void),gtk_image_get_type(void),gtk_label_get_type(void),gtk_box_get_type(void),gtk_button_box_get_type(void);
extern Obj g_type_class_ref(Type),g_value_get_object(const void *),g_object_ref(Obj),g_object_get_data(Obj,const char *);
extern void g_object_get(Obj,const char *,...),g_free(Obj);
extern void g_module_make_resident(Obj);
extern const char *g_module_name(Obj);
static const char *module_path=NULL;
__attribute__((visibility("default"))) const char *g_module_check_init(Obj module){g_module_make_resident(module);module_path=g_module_name(module);return NULL;}
extern int gtk_widget_get_realized(Obj),gtk_widget_get_mapped(Obj);
extern Obj gtk_settings_get_default(void),gtk_css_provider_new(void),gdk_screen_get_default(void);
extern const char *g_get_home_dir(void);
extern char *g_strdup_printf(const char *,...);
extern int gtk_css_provider_load_from_path(Obj,const char *,Obj);
extern void gtk_style_context_add_provider_for_screen(Obj,Obj,UInt);
extern void gtk_image_set_from_icon_name(Obj,const char *,int),gtk_image_set_pixel_size(Obj,int);
extern void g_object_unref(Obj),g_object_set_data(Obj,const char *,Obj),g_list_free(List *);
extern int g_type_check_instance_is_a(Obj,Type);
extern UInt g_signal_lookup(const char *,Type),g_idle_add(int (*)(Obj),Obj);
extern unsigned long g_signal_add_emission_hook(UInt,UInt,int (*)(Obj,UInt,const void *,Obj),Obj,void (*)(Obj));
extern Obj gtk_message_dialog_get_message_area(Obj),gtk_dialog_get_action_area(Obj),gtk_widget_get_parent(Obj),gtk_widget_get_style_context(Obj);
extern List *gtk_container_get_children(Obj);
extern void gtk_orientable_set_orientation(Obj,int),gtk_box_set_spacing(Obj,int),gtk_box_reorder_child(Obj,Obj,int),gtk_button_box_set_layout(Obj,int);
extern void gtk_widget_set_halign(Obj,int),gtk_widget_set_hexpand(Obj,int),gtk_widget_set_margin_start(Obj,int),gtk_widget_set_margin_end(Obj,int),gtk_widget_set_size_request(Obj,int,int);
extern void gtk_label_set_xalign(Obj,float),gtk_label_set_line_wrap(Obj,int),gtk_label_set_line_wrap_mode(Obj,int),gtk_label_set_max_width_chars(Obj,int);
extern void gtk_style_context_add_class(Obj,const char *),gtk_style_context_remove_class(Obj,const char *);
extern int gtk_style_context_has_class(Obj,const char *),gtk_widget_has_default(Obj),gtk_dialog_get_response_for_widget(Obj,Obj);
extern void gtk_window_resize(Obj,int,int),gtk_window_set_decorated(Obj,int),gtk_container_set_border_width(Obj,UInt);
static int is(Obj o,Type t){return o && g_type_check_instance_is_a(o,t);}
static int style_dialog(Obj dialog) {
    if(!gtk_widget_get_realized(dialog) || !gtk_widget_get_mapped(dialog)){g_object_unref(dialog);return 0;}
    Obj area=gtk_message_dialog_get_message_area(dialog);if(!area){g_object_unref(dialog);return 0;}
    Obj row=gtk_widget_get_parent(area);
    gtk_style_context_add_class(gtk_widget_get_style_context(dialog),"macshell-alert");
    if(is(row,gtk_box_get_type())) {
        gtk_orientable_set_orientation(row,1);gtk_box_set_spacing(row,20);gtk_container_set_border_width(row,0);gtk_widget_set_margin_start(row,6);gtk_widget_set_margin_end(row,6);
        List *children=gtk_container_get_children(row);
        for(List *p=children;p;p=p->next)if(is(p->data,gtk_image_get_type())){
            gtk_widget_set_halign(p->data,1);gtk_widget_set_margin_start(p->data,0);gtk_widget_set_margin_end(p->data,0);gtk_widget_set_size_request(p->data,64,64);
            int type=4;g_object_get(dialog,"message-type",&type,NULL);
            const char *icons[]={"dialog-information","dialog-warning","dialog-question","dialog-error"};
            if(type>=0 && type<4){gtk_image_set_from_icon_name(p->data,icons[type],6);gtk_image_set_pixel_size(p->data,64);}
        }
        g_list_free(children);
    }
    gtk_widget_set_halign(area,0);gtk_widget_set_hexpand(area,1);
    if(is(area,gtk_box_get_type()))gtk_box_set_spacing(area,12);
    List *labels=gtk_container_get_children(area);
    for(List *p=labels;p;p=p->next)if(is(p->data,gtk_label_get_type())) {
        gtk_widget_set_halign(p->data,0);gtk_widget_set_hexpand(p->data,1);gtk_label_set_xalign(p->data,0);gtk_label_set_line_wrap(p->data,1);
        gtk_label_set_line_wrap_mode(p->data,2);gtk_label_set_max_width_chars(p->data,26);
    }
    g_list_free(labels);
    Obj content=gtk_widget_get_parent(row);if(is(content,gtk_box_get_type())){gtk_box_set_spacing(content,18);gtk_container_set_border_width(content,0);}
    Obj actions=gtk_dialog_get_action_area(dialog),parent=gtk_widget_get_parent(actions),primary=NULL;
    if(is(parent,gtk_box_get_type()))gtk_orientable_set_orientation(parent,1);
    if(is(actions,gtk_box_get_type())) {
        gtk_orientable_set_orientation(actions,1);gtk_box_set_spacing(actions,8);gtk_container_set_border_width(actions,0);
        if(is(actions,gtk_button_box_get_type()))gtk_button_box_set_layout(actions,6);
        gtk_style_context_remove_class(gtk_widget_get_style_context(actions),"linked");
        gtk_widget_set_halign(actions,0);gtk_widget_set_hexpand(actions,1);
        List *buttons=gtk_container_get_children(actions);if(buttons)gtk_window_set_decorated(dialog,0);
        for(List *p=buttons;p;p=p->next) {
            Obj b=p->data,ctx=gtk_widget_get_style_context(b);
            gtk_widget_set_halign(b,0);gtk_widget_set_hexpand(b,1);
            gtk_widget_set_margin_start(b,0);gtk_widget_set_margin_end(b,0);
            int response=gtk_dialog_get_response_for_widget(dialog,b);
            if(gtk_style_context_has_class(ctx,"suggested-action") || gtk_style_context_has_class(ctx,"destructive-action") || response==-3 || response==-5 || response==-8 || response==-10)primary=b;
            else if(!primary && gtk_widget_has_default(b) && response!=-6 && response!=-9)primary=b;
        }
        if(primary)gtk_box_reorder_child(actions,primary,0);
        g_list_free(buttons);
    }
    gtk_widget_set_size_request(dialog,320,-1);gtk_window_resize(dialog,320,1);
    g_object_unref(dialog);return 0;
}
static int on_map(Obj hint,UInt n,const void *values,Obj unused) {
    (void)hint;(void)n;(void)unused;if(getenv("MACSHELL_SECURE_SURFACE"))return 1;
    Obj widget=g_value_get_object(values);
    if(!is(widget,gtk_message_dialog_get_type()))return 1;
    char *theme=NULL,*modules=NULL;g_object_get(gtk_settings_get_default(),"gtk-theme-name",&theme,"gtk-modules",&modules,NULL);
    const char *env=getenv("GTK_MODULES");
    int selected=module_path && ((modules && strstr(modules,module_path)) || (env && strstr(env,module_path)));
    int active=theme && !strncmp(theme,"MacShell",8) && selected;g_free(theme);g_free(modules);if(!active)return 1;
    if(is(widget,gtk_message_dialog_get_type()) && !g_object_get_data(widget,"macshell-dialog-styled-compact-v4")) {
        g_object_set_data(widget,"macshell-dialog-styled-compact-v4",(Obj)1);
        g_idle_add(style_dialog,g_object_ref(widget));
    }
    return 1;
}
__attribute__((visibility("default"))) void gtk_module_init(int *argc,char ***argv) {
    (void)argc;(void)argv;if(getenv("MACSHELL_SECURE_SURFACE"))return;g_type_class_ref(gtk_widget_get_type());
    Obj css=gtk_css_provider_new();char *path=g_strdup_printf("%s/.themes/MacShell-Apps/gtk-3.0/macshell-popups.css",g_get_home_dir());
    if(gtk_css_provider_load_from_path(css,path,NULL))gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),css,800);
    g_object_unref(css);g_free(path);
    UInt signal=g_signal_lookup("map",gtk_widget_get_type());
    if(signal)g_signal_add_emission_hook(signal,0,on_map,NULL,NULL);
}
