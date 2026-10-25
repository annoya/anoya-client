#ifndef RUNNER_NOTIFIER_H_
#define RUNNER_NOTIFIER_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

typedef struct _Notifier Notifier;

Notifier* notifier_new(GtkWindow* window, FlBinaryMessenger* messenger);

void notifier_free(Notifier* self);

#endif  // RUNNER_NOTIFIER_H_
