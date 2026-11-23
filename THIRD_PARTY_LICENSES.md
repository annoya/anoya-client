# Third-Party Licenses

This project is licensed under the GNU General Public License v3.0.
This file lists third-party software components used by this repository.
Each component is distributed under its own license as linked below.

---

## mihomo

- Source: https://github.com/MetaCubeX/mihomo
- License: GNU General Public License v3.0 (GPL-3.0) at the pinned version (`v1.19.33`)
- License Text: https://github.com/MetaCubeX/mihomo/blob/v1.19.33/LICENSE

---

## sing and its protocol modules

- Source: https://github.com/MetaCubeX/sing, https://github.com/MetaCubeX/sing-tun
  and the other `sing-*` modules (forks of https://github.com/SagerNet)
- License: GNU General Public License v3.0 or later (GPL-3.0-or-later);
  `sing-wireguard` is GPL-3.0
- License Text: https://github.com/MetaCubeX/sing-tun/blob/meta/LICENSE

---

## gVisor

- Source: https://github.com/metacubex/gvisor (fork of https://github.com/google/gvisor)
- License: Apache License 2.0
- License Text: https://github.com/google/gvisor/blob/master/LICENSE

---

## AmneziaWG Go

- Source: https://github.com/metacubex/amneziawg-go (fork of https://github.com/amnezia-vpn/amneziawg-go)
- License: MIT License
- License Text: https://github.com/amnezia-vpn/amneziawg-go/blob/master/LICENSE

---

## WireGuard Go

- Source: https://github.com/metacubex/wireguard-go (fork of https://git.zx2c4.com/wireguard-go)
- License: MIT License
- License Text: https://git.zx2c4.com/wireguard-go/tree/LICENSE

---

## Go modules of the engine

Every Go module linked into the engine (`native/mihomocore`: the Apple
xcframework, the Android AAR and the Windows and Linux tunnel service), at the
versions pinned in `native/mihomocore/go.sum`. Each is distributed under the
license in its own repository at that version. The Go standard library and
runtime are BSD 3-Clause.

| Module | License |
|---|---|
| `github.com/andybalholm/brotli` | MIT |
| `github.com/bahlo/generic-list-go` | BSD 3-Clause |
| `github.com/bodgit/plumbing` | BSD 3-Clause |
| `github.com/bodgit/windows` | BSD 3-Clause |
| `github.com/coreos/go-iptables` | Apache 2.0 |
| `github.com/dlclark/regexp2` | MIT |
| `github.com/dunglas/httpsfv` | BSD 3-Clause |
| `github.com/easytier/easytier/easytier-go` | LGPL-3.0 |
| `github.com/enfein/mieru/v3` | GPL-3.0 |
| `github.com/ericlagergren/aegis` | BSD 2-Clause |
| `github.com/ericlagergren/polyval` | BSD 2-Clause |
| `github.com/ericlagergren/siv` | BSD 3-Clause |
| `github.com/ericlagergren/subtle` | BSD 3-Clause |
| `github.com/fsnotify/fsnotify` | BSD 3-Clause |
| `github.com/fxamacker/cbor/v2` | MIT |
| `github.com/gaukas/godicttls` | BSD 3-Clause |
| `github.com/go-ole/go-ole` | MIT |
| `github.com/gobwas/httphead` | MIT |
| `github.com/gobwas/pool` | MIT |
| `github.com/gobwas/ws` | MIT |
| `github.com/gofrs/uuid/v5` | MIT |
| `github.com/golang/groupcache` | Apache 2.0 |
| `github.com/golang/snappy` | BSD 3-Clause |
| `github.com/google/btree` | Apache 2.0 |
| `github.com/google/pprof` | Apache 2.0 |
| `github.com/hashicorp/golang-lru/v2` | MPL 2.0 |
| `github.com/insomniacslk/dhcp` | BSD 3-Clause |
| `github.com/josharian/native` | MIT |
| `github.com/jsimonetti/rtnetlink` | MIT |
| `github.com/klauspost/compress` | BSD 3-Clause, Apache 2.0 |
| `github.com/klauspost/cpuid/v2` | MIT |
| `github.com/klauspost/reedsolomon` | MIT |
| `github.com/mdlayher/netlink` | MIT |
| `github.com/mdlayher/socket` | MIT |
| `github.com/metacubex/age` | BSD 3-Clause |
| `github.com/metacubex/amneziawg-go` | MIT |
| `github.com/metacubex/ascon` | BSD 3-Clause |
| `github.com/metacubex/bart` | MIT |
| `github.com/metacubex/bbolt` | MIT |
| `github.com/metacubex/blake3` | MIT |
| `github.com/metacubex/chacha` | MIT |
| `github.com/metacubex/chi` | MIT |
| `github.com/metacubex/connect-ip-go` | MIT |
| `github.com/metacubex/cpu` | BSD 3-Clause |
| `github.com/metacubex/edwards25519` | BSD 3-Clause |
| `github.com/metacubex/fswatch` | GPL-3.0-or-later |
| `github.com/metacubex/gopacket` | BSD 3-Clause |
| `github.com/metacubex/gvisor` | Apache 2.0 |
| `github.com/metacubex/hkdf` | BSD 3-Clause |
| `github.com/metacubex/hpke` | BSD 3-Clause |
| `github.com/metacubex/http` | BSD 3-Clause |
| `github.com/metacubex/jls-quic-go` | MIT |
| `github.com/metacubex/jls-tls` | BSD 3-Clause |
| `github.com/metacubex/jsonv2` | BSD 3-Clause |
| `github.com/metacubex/kcp-go` | MIT |
| `github.com/metacubex/mhurl` | BSD 3-Clause |
| `github.com/metacubex/mihomo` | GPL-3.0 |
| `github.com/metacubex/mipstack` | MPL 2.0 |
| `github.com/metacubex/mlkem` | BSD 3-Clause |
| `github.com/metacubex/nftables` | Apache 2.0 |
| `github.com/metacubex/qpack` | MIT |
| `github.com/metacubex/quic-go` | MIT |
| `github.com/metacubex/randv2` | GPL-3.0 |
| `github.com/metacubex/restls-client-go` | BSD 3-Clause |
| `github.com/metacubex/sevenzip` | BSD 3-Clause |
| `github.com/metacubex/sing` | GPL-3.0-or-later |
| `github.com/metacubex/sing-mux` | GPL-3.0-or-later |
| `github.com/metacubex/sing-quic` | GPL-3.0-or-later |
| `github.com/metacubex/sing-shadowsocks` | GPL-3.0-or-later |
| `github.com/metacubex/sing-shadowsocks2` | GPL-3.0-or-later |
| `github.com/metacubex/sing-tun` | GPL-3.0-or-later |
| `github.com/metacubex/sing-vmess` | GPL-3.0-or-later |
| `github.com/metacubex/sing-wireguard` | GPL-3.0 |
| `github.com/metacubex/smux` | MIT |
| `github.com/metacubex/ssh` | BSD 3-Clause |
| `github.com/metacubex/tailscale` | BSD 3-Clause |
| `github.com/metacubex/tailscale-wireguard-go` | MIT |
| `github.com/metacubex/tfo-go` | MIT |
| `github.com/metacubex/tls` | BSD 3-Clause |
| `github.com/metacubex/utls` | BSD 3-Clause |
| `github.com/metacubex/wazero` | Apache 2.0 |
| `github.com/metacubex/wireguard-go` | MIT |
| `github.com/metacubex/yamux` | MPL 2.0 (parts BSD 3-Clause) |
| `github.com/metacubex/zerotier-go` | MPL 2.0 |
| `github.com/miekg/dns` | BSD 3-Clause |
| `github.com/mitchellh/go-ps` | MIT |
| `github.com/mroth/weightedrand/v2` | MIT |
| `github.com/oasisprotocol/deoxysii` | MIT |
| `github.com/openacid/low` | MIT |
| `github.com/oschwald/maxminddb-golang` | ISC |
| `github.com/pierrec/lz4/v4` | BSD 3-Clause |
| `github.com/pires/go-proxyproto` | Apache 2.0 |
| `github.com/rasky/go-lzo` | GPL-2.0 |
| `github.com/RyuaNerin/go-krypto` | MIT |
| `github.com/safchain/ethtool` | Apache 2.0 |
| `github.com/sagernet/netlink` | Apache 2.0 |
| `github.com/samber/lo` | MIT |
| `github.com/sina-ghaderi/poly1305` | GPL-3.0 |
| `github.com/sina-ghaderi/rabaead` | GPL-3.0 |
| `github.com/sina-ghaderi/rabbitio` | Apache 2.0 |
| `github.com/sirupsen/logrus` | MIT |
| `github.com/stangelandcl/ppmd` | MIT |
| `github.com/tailscale/certstore` | MIT |
| `github.com/tailscale/go-winio` | MIT |
| `github.com/tailscale/hujson` | BSD 3-Clause |
| `github.com/tailscale/peercred` | BSD 3-Clause |
| `github.com/u-root/uio` | BSD 3-Clause |
| `github.com/ulikunitz/xz` | BSD 3-Clause |
| `github.com/vishvananda/netns` | Apache 2.0 |
| `github.com/vmihailenco/msgpack/v5` | BSD 2-Clause |
| `github.com/vmihailenco/tagparser/v2` | BSD 2-Clause |
| `github.com/x448/float16` | MIT |
| `github.com/Yawning/aez` | CC0 1.0 |
| `github.com/yosida95/uritemplate/v3` | BSD 3-Clause |
| `gitlab.com/go-extension/aes-ccm` | MIT |
| `gitlab.com/yawning/bsaes.git` | MIT |
| `go.yaml.in/yaml/v3` | Apache 2.0 |
| `go4.org/mem` | Apache 2.0 |
| `go4.org/netipx` | BSD 3-Clause |
| `golang.org/x/crypto` | BSD 3-Clause |
| `golang.org/x/exp` | BSD 3-Clause |
| `golang.org/x/mobile` | BSD 3-Clause |
| `golang.org/x/net` | BSD 3-Clause |
| `golang.org/x/sync` | BSD 3-Clause |
| `golang.org/x/sys` | BSD 3-Clause |
| `golang.org/x/term` | BSD 3-Clause |
| `golang.org/x/text` | BSD 3-Clause |
| `golang.org/x/time` | BSD 3-Clause |
| `google.golang.org/protobuf` | BSD 3-Clause |

---

## libagw

- Source: https://github.com/amnezia-vpn/libagw (pinned tag `v1.0.8`)
- License: GNU General Public License v3.0 (GPL-3.0); the license file was
  added to the repository after the pinned tag
- License Text: https://github.com/amnezia-vpn/libagw/blob/master/LICENSE

---

## Wintun

- Source: https://www.wintun.net
- License: Prebuilt Binaries License (for the shipped `wintun.dll`, `0.14.1`)
- License Text: https://github.com/WireGuard/wintun/blob/master/prebuilt-binaries-license.txt

---

## zxing-cpp

- Source: https://github.com/zxing-cpp/zxing-cpp (bundled by `flutter_zxing`)
- License: Apache License 2.0
- License Text: https://github.com/zxing-cpp/zxing-cpp/blob/master/LICENSE

---

## Flutter

- Source: https://github.com/flutter/flutter (including `flutter_localizations`)
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
| file_picker | https://github.com/vicajilau/flutter_file_picker | MIT License | https://pub.dev/packages/file_picker/license |
| flutter_riverpod | https://github.com/rrousselGit/riverpod | MIT License | https://pub.dev/packages/flutter_riverpod/license |
| flutter_secure_storage | https://github.com/mogol/flutter_secure_storage | BSD 3-Clause License | https://pub.dev/packages/flutter_secure_storage/license |
| flutter_svg | https://github.com/flutter/packages | MIT License | https://pub.dev/packages/flutter_svg/license |
| flutter_zxing | https://github.com/khoren93/flutter_zxing | MIT License | https://pub.dev/packages/flutter_zxing/license |
| http | https://github.com/dart-lang/http | BSD 3-Clause License | https://pub.dev/packages/http/license |
| image_picker | https://github.com/flutter/packages | BSD 3-Clause License, Apache License 2.0 | https://pub.dev/packages/image_picker/license |
| intl | https://github.com/dart-lang/i18n | BSD 3-Clause License | https://pub.dev/packages/intl/license |
| path_provider | https://github.com/flutter/packages | BSD 3-Clause License | https://pub.dev/packages/path_provider/license |
| share_plus | https://github.com/fluttercommunity/plus_plugins | BSD 3-Clause License | https://pub.dev/packages/share_plus/license |
| url_launcher | https://github.com/flutter/packages | BSD 3-Clause License | https://pub.dev/packages/url_launcher/license |
| win32 | https://github.com/halildurmus/win32 | BSD 3-Clause License | https://pub.dev/packages/win32/license |
| yaml | https://github.com/dart-lang/tools | MIT License | https://pub.dev/packages/yaml/license |

Their transitive dependencies are pinned in `pubspec.lock`; each is
distributed under the license on its pub.dev page. All of them are MIT, BSD or
Apache 2.0, except `dbus` (Mozilla Public License 2.0, used on Linux).

---

## Simple Icons

- Source: https://github.com/simple-icons/simple-icons
- License: CC0 1.0 Universal (the brand glyphs in `assets/brands/`)
- License Text: https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md
- The brands themselves are trademarks of their owners.

---

## Lucide

- Source: https://github.com/lucide-icons/lucide (lucide-static 0.460.0)
- License: ISC License, with portions from Feather under the MIT License
  (the interface icons in `assets/icons/`)
- License Text: https://github.com/lucide-icons/lucide/blob/main/LICENSE

---

## Data downloaded at runtime

Not shipped with the app. When geo rules are in use, the app downloads the
GeoIP and GeoSite databases from their configured source, by default:

- Source: https://github.com/MetaCubeX/meta-rules-dat
- License: GNU General Public License v3.0 (GPL-3.0)
- License Text: https://github.com/MetaCubeX/meta-rules-dat/blob/master/LICENSE
