# Third-Party Licenses

This project is licensed under the GNU General Public License v3.0.
This file lists third-party software components used by this repository.
Each component is distributed under its own license as linked below.

---

## mihomo

- Source: https://github.com/MetaCubeX/mihomo
- License: GNU General Public License v3.0 (GPL-3.0)
- License Text: https://pkg.go.dev/github.com/metacubex/mihomo?tab=licenses

---

## sing / sing-tun

- Source: https://github.com/MetaCubeX/sing-tun (fork of https://github.com/SagerNet/sing-tun)
- License: GNU General Public License v3.0 (GPL-3.0)
- License Text: https://pkg.go.dev/github.com/metacubex/sing-tun?tab=licenses

---

## gVisor

- Source: https://github.com/metacubex/gvisor (fork of https://github.com/google/gvisor)
- License: Apache License 2.0
- License Text: https://pkg.go.dev/github.com/metacubex/gvisor?tab=licenses

---

## AmneziaWG Go

- Source: https://github.com/metacubex/amneziawg-go (fork of https://github.com/amnezia-vpn/amneziawg-go)
- License: MIT License
- License Text: https://pkg.go.dev/github.com/metacubex/amneziawg-go?tab=licenses

---

## Other Go modules of the engine

The engine links further Go modules through mihomo. The complete list, with
versions, is `native/mihomocore/go.sum`; each module is distributed under the
license in its own repository. The Windows service adds these directly:

- logrus — https://github.com/sirupsen/logrus — MIT License
- go-winio — https://github.com/tailscale/go-winio — MIT License
- golang.org/x/sys — https://go.googlesource.com/sys — BSD 3-Clause License

---

## libagw

- Source: https://github.com/amnezia-vpn/libagw
- License: not stated in the repository at the pinned commit (`2f0215b`)
- License Text: —

---

## Wintun

- Source: https://www.wintun.net
- License: Prebuilt Binaries License (for the shipped `wintun.dll`)
- License Text: https://github.com/WireGuard/wintun/blob/master/prebuilt-binaries-license.txt

---

## zxing-cpp

- Source: https://github.com/zxing-cpp/zxing-cpp
- License: Apache License 2.0
- License Text: https://github.com/zxing-cpp/zxing-cpp/blob/master/LICENSE

---

## Flutter

- Source: https://github.com/flutter/flutter
- License: BSD 3-Clause License
- License Text: https://github.com/flutter/flutter/blob/master/LICENSE

---

## Dart and Flutter packages

| Package | Source | License | License Text |
|---|---|---|---|
| archive | https://github.com/brendan-duncan/archive | MIT License | https://pub.dev/packages/archive/license |
| camera | https://github.com/flutter/packages | BSD 3-Clause License | https://pub.dev/packages/camera/license |
| crypto | https://github.com/dart-lang/core | BSD 3-Clause License | https://pub.dev/packages/crypto/license |
| cryptography | https://github.com/dint-dev/cryptography | Apache License 2.0 | https://pub.dev/packages/cryptography/license |
| cupertino_icons | https://github.com/flutter/packages | MIT License | https://pub.dev/packages/cupertino_icons/license |
| ffi | https://github.com/dart-lang/native | BSD 3-Clause License | https://pub.dev/packages/ffi/license |
| file_picker | https://github.com/miguelpruivo/plugins_flutter_file_picker | MIT License | https://pub.dev/packages/file_picker/license |
| flutter_riverpod | https://github.com/rrousselGit/riverpod | MIT License | https://pub.dev/packages/flutter_riverpod/license |
| flutter_secure_storage | https://github.com/mogol/flutter_secure_storage | BSD 3-Clause License | https://pub.dev/packages/flutter_secure_storage/license |
| flutter_svg | https://github.com/flutter/packages | MIT License | https://pub.dev/packages/flutter_svg/license |
| flutter_zxing | https://github.com/khoren93/flutter_zxing | MIT License | https://pub.dev/packages/flutter_zxing/license |
| http | https://github.com/dart-lang/http | BSD 3-Clause License | https://pub.dev/packages/http/license |
| image_picker | https://github.com/flutter/packages | BSD 3-Clause License | https://pub.dev/packages/image_picker/license |
| intl | https://github.com/dart-lang/i18n | BSD 3-Clause License | https://pub.dev/packages/intl/license |
| path_provider | https://github.com/flutter/packages | BSD 3-Clause License | https://pub.dev/packages/path_provider/license |
| share_plus | https://github.com/fluttercommunity/plus_plugins | BSD 3-Clause License | https://pub.dev/packages/share_plus/license |
| url_launcher | https://github.com/flutter/packages | BSD 3-Clause License | https://pub.dev/packages/url_launcher/license |
| yaml | https://github.com/dart-lang/tools | MIT License | https://pub.dev/packages/yaml/license |

Their transitive dependencies are pinned in `pubspec.lock`; each is
distributed under the license on its pub.dev page.

---

## Simple Icons

- Source: https://github.com/simple-icons/simple-icons
- License: CC0 1.0 Universal (the brand glyphs in `assets/brands/`)
- License Text: https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md
- The brands themselves are trademarks of their owners.
