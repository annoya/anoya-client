#include "notifier.h"

#include <cstring>

namespace {

constexpr const char* kAppName = "Anoya";
constexpr const char* kIconName = "anoya";
constexpr const char* kBusName = "org.freedesktop.Notifications";
constexpr const char* kObjectPath = "/org/freedesktop/Notifications";
constexpr const char* kInterface = "org.freedesktop.Notifications";

}  // namespace

struct _Notifier {
  GtkWindow* window;
  FlMethodChannel* channel;
  GDBusConnection* bus;
  guint action_signal;
  GHashTable* ids;
  GHashTable* actions;
};

static const gchar* lookup_string(FlValue* map, const char* key) {
  FlValue* value = fl_value_lookup_string(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(value)
             : nullptr;
}

struct Pending {
  Notifier* self;
  gchar* id;
  gchar* action;
};

static void notify_done_cb(GObject* source, GAsyncResult* res,
                           gpointer user_data) {
  Pending* pending = static_cast<Pending*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) reply =
      g_dbus_connection_call_finish(G_DBUS_CONNECTION(source), res, &error);
  if (reply != nullptr) {
    guint32 id = 0;
    g_variant_get(reply, "(u)", &id);
    g_hash_table_replace(pending->self->ids, g_strdup(pending->id),
                         GUINT_TO_POINTER(id));
    if (pending->action != nullptr) {
      g_hash_table_replace(pending->self->actions, GUINT_TO_POINTER(id),
                           g_strdup(pending->action));
    }
  } else {
    g_message("notifications: %s", error->message);
  }
  g_free(pending->id);
  g_free(pending->action);
  g_free(pending);
}

static void notify(Notifier* self, FlValue* args) {
  const gchar* id = lookup_string(args, "id");
  const gchar* title = lookup_string(args, "title");
  const gchar* body = lookup_string(args, "body");
  const gchar* action = lookup_string(args, "action");
  if (id == nullptr || self->bus == nullptr) return;
  const guint32 replaces = GPOINTER_TO_UINT(g_hash_table_lookup(self->ids, id));

  GVariantBuilder actions;
  g_variant_builder_init(&actions, G_VARIANT_TYPE("as"));
  if (action != nullptr) {
    g_variant_builder_add(&actions, "s", "default");
    g_variant_builder_add(&actions, "s", "");
  }
  GVariantBuilder hints;
  g_variant_builder_init(&hints, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&hints, "{sv}", "desktop-entry",
                        g_variant_new_string(APPLICATION_ID));

  Pending* pending = g_new0(Pending, 1);
  pending->self = self;
  pending->id = g_strdup(id);
  pending->action = g_strdup(action);
  g_dbus_connection_call(
      self->bus, kBusName, kObjectPath, kInterface, "Notify",
      g_variant_new("(susssasa{sv}i)", kAppName, replaces, kIconName,
                    title != nullptr ? title : "", body != nullptr ? body : "",
                    &actions, &hints, -1),
      G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, -1, nullptr,
      notify_done_cb, pending);
}

static void withdraw(Notifier* self, FlValue* args) {
  const gchar* id = lookup_string(args, "id");
  if (id == nullptr || self->bus == nullptr) return;
  const guint32 shown = GPOINTER_TO_UINT(g_hash_table_lookup(self->ids, id));
  if (shown == 0) return;
  g_hash_table_remove(self->ids, id);
  g_hash_table_remove(self->actions, GUINT_TO_POINTER(shown));
  g_dbus_connection_call(self->bus, kBusName, kObjectPath, kInterface,
                         "CloseNotification", g_variant_new("(u)", shown),
                         nullptr, G_DBUS_CALL_FLAGS_NONE, -1, nullptr, nullptr,
                         nullptr);
}

static void action_invoked_cb(GDBusConnection* bus, const gchar* sender,
                              const gchar* path, const gchar* interface,
                              const gchar* signal, GVariant* params,
                              gpointer user_data) {
  Notifier* self = static_cast<Notifier*>(user_data);
  guint32 id = 0;
  const gchar* key = nullptr;
  g_variant_get(params, "(u&s)", &id, &key);
  const gchar* action = static_cast<const gchar*>(
      g_hash_table_lookup(self->actions, GUINT_TO_POINTER(id)));
  if (action == nullptr) return;
  gtk_widget_show(GTK_WIDGET(self->window));
  gtk_window_present(self->window);
  g_autoptr(FlValue) value = fl_value_new_string(action);
  fl_method_channel_invoke_method(self->channel, "clicked", value, nullptr,
                                  nullptr, nullptr);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  Notifier* self = static_cast<Notifier*>(user_data);
  FlValue* args = fl_method_call_get_args(call);
  const gchar* name = fl_method_call_get_name(call);
  const gboolean is_map =
      args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP;
  if (strcmp(name, "notify") == 0 && is_map) {
    notify(self, args);
  } else if (strcmp(name, "withdraw") == 0 && is_map) {
    withdraw(self, args);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
}

Notifier* notifier_new(GtkWindow* window, FlBinaryMessenger* messenger) {
  Notifier* self = g_new0(Notifier, 1);
  self->window = window;
  self->ids = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, nullptr);
  self->actions = g_hash_table_new_full(g_direct_hash, g_direct_equal, nullptr,
                                        g_free);
  g_autoptr(GError) error = nullptr;
  self->bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (self->bus == nullptr) {
    g_message("notifications: no session bus: %s", error->message);
  } else {
    self->action_signal = g_dbus_connection_signal_subscribe(
        self->bus, kBusName, kInterface, "ActionInvoked", kObjectPath, nullptr,
        G_DBUS_SIGNAL_FLAGS_NONE, action_invoked_cb, self, nullptr);
  }
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel = fl_method_channel_new(messenger, "vpn/notify",
                                        FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->channel, method_call_cb,
                                            self, nullptr);
  return self;
}

void notifier_free(Notifier* self) {
  if (self == nullptr) return;
  fl_method_channel_set_method_call_handler(self->channel, nullptr, nullptr,
                                            nullptr);
  if (self->bus != nullptr && self->action_signal != 0) {
    g_dbus_connection_signal_unsubscribe(self->bus, self->action_signal);
  }
  g_clear_object(&self->bus);
  g_clear_object(&self->channel);
  g_hash_table_destroy(self->ids);
  g_hash_table_destroy(self->actions);
  g_free(self);
}
