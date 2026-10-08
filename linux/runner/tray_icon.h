#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

typedef struct _TrayIcon TrayIcon;

TrayIcon* tray_icon_new(GApplication* application, GtkWindow* window,
                        FlBinaryMessenger* messenger);

gboolean tray_icon_is_shown(TrayIcon* self);

void tray_icon_free(TrayIcon* self);

#endif  // RUNNER_TRAY_ICON_H_
