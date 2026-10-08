#include "tray_icon.h"

#include <dlfcn.h>

#include <cstring>
#include <initializer_list>

namespace {

constexpr int kCategoryApplicationStatus = 0;
constexpr int kStatusActive = 1;
constexpr guint kWinkIntervalSeconds = 1;
constexpr const char* kAppName = "Anoya";

using IndicatorNew = GObject* (*)(const gchar*, const gchar*, int);
using IndicatorSetStatus = void (*)(GObject*, int);
using IndicatorSetMenu = void (*)(GObject*, GtkMenu*);
using IndicatorSetIcon = void (*)(GObject*, const gchar*, const gchar*);
using IndicatorSetTitle = void (*)(GObject*, const gchar*);

struct IndicatorApi {
  IndicatorNew create = nullptr;
  IndicatorSetStatus set_status = nullptr;
  IndicatorSetMenu set_menu = nullptr;
  IndicatorSetIcon set_icon = nullptr;
  IndicatorSetTitle set_title = nullptr;
};

bool LoadIndicatorApi(IndicatorApi* api) {
  for (const char* name :
       {"libayatana-appindicator3.so.1", "libappindicator3.so.1"}) {
    void* lib = dlopen(name, RTLD_NOW | RTLD_LOCAL);
    if (lib == nullptr) continue;
    api->create = reinterpret_cast<IndicatorNew>(dlsym(lib, "app_indicator_new"));
    api->set_status =
        reinterpret_cast<IndicatorSetStatus>(dlsym(lib, "app_indicator_set_status"));
    api->set_menu =
        reinterpret_cast<IndicatorSetMenu>(dlsym(lib, "app_indicator_set_menu"));
    api->set_icon =
        reinterpret_cast<IndicatorSetIcon>(dlsym(lib, "app_indicator_set_icon_full"));
    api->set_title =
        reinterpret_cast<IndicatorSetTitle>(dlsym(lib, "app_indicator_set_title"));
    if (api->create && api->set_status && api->set_menu && api->set_icon &&
        api->set_title) {
      return true;
    }
    dlclose(lib);
  }
  return false;
}

enum Frame { kClosed, kOpen, kWinkLeft, kWinkRight, kFrameCount };

const char* kFrameNames[kFrameCount] = {"closed", "open", "winkL", "winkR"};

}  // namespace

struct _TrayIcon {
  GApplication* application;
  GtkWindow* window;
  FlMethodChannel* channel;
  IndicatorApi api;
  GObject* indicator;
  GtkWidget* menu;
  GtkWidget* status_item;
  GtkWidget* detail_item;
  GtkWidget* window_item;
  GtkWidget* connect_item;
  GtkWidget* disconnect_item;
  GtkWidget* quit_note_item;
  gchar* frames[kFrameCount];
  Frame shown_frame;
  gboolean host_connected;
  gboolean tunnel_up;
  gboolean connecting;
  gboolean wink_right;
  guint wink_timer;
};

static gboolean animations_enabled() {
  gboolean enabled = TRUE;
  g_object_get(gtk_settings_get_default(), "gtk-enable-animations", &enabled,
               nullptr);
  return enabled;
}

static Frame current_frame(TrayIcon* self) {
  if (self->connecting) return self->wink_right ? kWinkRight : kWinkLeft;
  return self->tunnel_up ? kOpen : kClosed;
}

static void show_frame(TrayIcon* self) {
  const Frame frame = current_frame(self);
  if (frame == self->shown_frame) return;
  self->shown_frame = frame;
  self->api.set_icon(self->indicator, self->frames[frame], kAppName);
}

static gboolean wink_cb(gpointer user_data) {
  TrayIcon* self = static_cast<TrayIcon*>(user_data);
  self->wink_right = !self->wink_right;
  show_frame(self);
  return G_SOURCE_CONTINUE;
}

static void set_connecting(TrayIcon* self, gboolean connecting) {
  if (connecting == self->connecting) return;
  self->connecting = connecting;
  self->wink_right = FALSE;
  if (connecting && animations_enabled()) {
    self->wink_timer = g_timeout_add_seconds(kWinkIntervalSeconds, wink_cb, self);
  } else if (!connecting && self->wink_timer != 0) {
    g_source_remove(self->wink_timer);
    self->wink_timer = 0;
  }
}

static void set_label(GtkWidget* item, const gchar* text) {
  gtk_menu_item_set_label(GTK_MENU_ITEM(item), text);
  gtk_widget_set_visible(item, text != nullptr && text[0] != '\0');
}

static const gchar* lookup_string(FlValue* map, const char* key) {
  FlValue* value = fl_value_lookup_string(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(value)
             : nullptr;
}

static gboolean lookup_bool(FlValue* map, const char* key) {
  FlValue* value = fl_value_lookup_string(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
         fl_value_get_bool(value);
}

static void apply(TrayIcon* self, FlValue* args) {
  if (const gchar* status = lookup_string(args, "status")) {
    set_label(self->status_item, status);
  }
  if (const gchar* detail = lookup_string(args, "detail")) {
    set_label(self->detail_item, detail);
  }
  gtk_widget_set_sensitive(self->connect_item, lookup_bool(args, "can_connect"));
  gtk_widget_set_sensitive(self->disconnect_item,
                           lookup_bool(args, "can_disconnect"));
  self->tunnel_up = lookup_bool(args, "tunnel_up");
  gtk_widget_set_visible(self->quit_note_item, self->tunnel_up);
  set_connecting(self, lookup_bool(args, "connecting"));
  show_frame(self);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  TrayIcon* self = static_cast<TrayIcon*>(user_data);
  if (strcmp(fl_method_call_get_name(call), "update") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      apply(self, args);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }
  fl_method_call_respond_not_implemented(call, nullptr);
}

static void invoke(TrayIcon* self, const char* method) {
  fl_method_channel_invoke_method(self->channel, method, nullptr, nullptr,
                                  nullptr, nullptr);
}

static void update_window_item(TrayIcon* self) {
  g_autofree gchar* label = g_strdup_printf(
      "%s %s",
      gtk_widget_get_visible(GTK_WIDGET(self->window)) ? "Hide" : "Show",
      kAppName);
  gtk_menu_item_set_label(GTK_MENU_ITEM(self->window_item), label);
}

static void window_visibility_cb(GObject* window, GParamSpec* pspec,
                                 gpointer user_data) {
  update_window_item(static_cast<TrayIcon*>(user_data));
}

static void toggle_window_cb(GtkMenuItem* item, gpointer user_data) {
  TrayIcon* self = static_cast<TrayIcon*>(user_data);
  if (gtk_widget_get_visible(GTK_WIDGET(self->window))) {
    gtk_widget_hide(GTK_WIDGET(self->window));
  } else {
    gtk_window_present(self->window);
  }
}

static void connect_cb(GtkMenuItem* item, gpointer user_data) {
  invoke(static_cast<TrayIcon*>(user_data), "connect");
}

static void disconnect_cb(GtkMenuItem* item, gpointer user_data) {
  invoke(static_cast<TrayIcon*>(user_data), "disconnect");
}

static void quit_cb(GtkMenuItem* item, gpointer user_data) {
  g_application_quit(static_cast<TrayIcon*>(user_data)->application);
}

static void host_connection_cb(GObject* indicator, gboolean connected,
                               gpointer user_data) {
  static_cast<TrayIcon*>(user_data)->host_connected = connected;
}

static GtkWidget* append_item(GtkWidget* menu, const gchar* label,
                              GCallback activate, gpointer user_data) {
  GtkWidget* item = gtk_menu_item_new_with_label(label);
  if (activate != nullptr) {
    g_signal_connect(item, "activate", activate, user_data);
  } else {
    gtk_widget_set_sensitive(item, FALSE);
  }
  gtk_widget_show(item);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
  return item;
}

static void append_separator(GtkWidget* menu) {
  GtkWidget* separator = gtk_separator_menu_item_new();
  gtk_widget_show(separator);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), separator);
}

static GtkWidget* build_menu(TrayIcon* self) {
  GtkWidget* menu = gtk_menu_new();
  self->status_item = append_item(menu, "Not connected", nullptr, nullptr);
  self->detail_item = append_item(menu, "", nullptr, nullptr);
  gtk_widget_hide(self->detail_item);
  append_separator(menu);
  self->window_item =
      append_item(menu, "", G_CALLBACK(toggle_window_cb), self);
  append_separator(menu);
  self->connect_item = append_item(menu, "Connect", G_CALLBACK(connect_cb), self);
  self->disconnect_item =
      append_item(menu, "Disconnect", G_CALLBACK(disconnect_cb), self);
  gtk_widget_set_sensitive(self->disconnect_item, FALSE);
  append_separator(menu);
  g_autofree gchar* quit = g_strdup_printf("Quit %s", kAppName);
  append_item(menu, quit, G_CALLBACK(quit_cb), self);
  self->quit_note_item = append_item(
      menu, "Quitting leaves the tunnel connected", nullptr, nullptr);
  gtk_widget_hide(self->quit_note_item);
  return menu;
}

static gchar* frame_path(const gchar* bundle_dir, const char* name) {
  g_autofree gchar* file = g_strdup_printf("tray_%s.png", name);
  return g_build_filename(bundle_dir, "data", "tray", file, nullptr);
}

TrayIcon* tray_icon_new(GApplication* application, GtkWindow* window,
                        FlBinaryMessenger* messenger) {
  IndicatorApi api;
  if (!LoadIndicatorApi(&api)) {
    g_message("tray: no AppIndicator library, running without a tray icon");
    return nullptr;
  }

  TrayIcon* self = g_new0(TrayIcon, 1);
  self->application = application;
  self->window = window;
  self->api = api;
  self->shown_frame = kFrameCount;

  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* bundle_dir =
      g_path_get_dirname(exe != nullptr ? exe : ".");
  for (int i = 0; i < kFrameCount; i++) {
    self->frames[i] = frame_path(bundle_dir, kFrameNames[i]);
  }

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel = fl_method_channel_new(messenger, "vpn/tray",
                                        FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->channel, method_call_cb,
                                            self, nullptr);

  self->menu = build_menu(self);
  g_object_ref_sink(self->menu);
  update_window_item(self);
  g_signal_connect(window, "notify::visible", G_CALLBACK(window_visibility_cb),
                   self);

  self->indicator = self->api.create(APPLICATION_ID, self->frames[kClosed],
                                     kCategoryApplicationStatus);
  g_signal_connect(self->indicator, "connection-changed",
                   G_CALLBACK(host_connection_cb), self);
  self->api.set_title(self->indicator, kAppName);
  self->api.set_menu(self->indicator, GTK_MENU(self->menu));
  self->api.set_status(self->indicator, kStatusActive);
  show_frame(self);
  return self;
}

gboolean tray_icon_is_shown(TrayIcon* self) {
  return self != nullptr && self->host_connected;
}

void tray_icon_free(TrayIcon* self) {
  if (self == nullptr) return;
  if (self->wink_timer != 0) g_source_remove(self->wink_timer);
  g_signal_handlers_disconnect_by_data(self->window, self);
  fl_method_channel_set_method_call_handler(self->channel, nullptr, nullptr,
                                            nullptr);
  g_clear_object(&self->indicator);
  g_clear_object(&self->menu);
  g_clear_object(&self->channel);
  for (int i = 0; i < kFrameCount; i++) g_free(self->frames[i]);
  g_free(self);
}
