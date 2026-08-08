#!/usr/bin/env bash
# Live leak check for the macOS tunnel. Run it with the VPN CONNECTED, then
# switch locations/configurations in the app while it watches.
#
#   sudo client/scripts/leak-check.sh            # runs until Ctrl-C
#   sudo client/scripts/leak-check.sh 120        # or for N seconds
#
# How it works: the script keeps generating traffic to a fixed set of public
# test IPs (TCP SYNs + system DNS lookups + ICMP) and captures BOTH the physical
# interface and the utun. While the tunnel session is alive every one of those
# packets must leave through utun — the only legitimate traffic on the physical
# interface is the tunnel's own encrypted flow to the VPN server, which is not
# in the filter.
#
# Any test packet on the physical interface fails the run — TCP, UDP, plain DNS
# or ICMP alike. ICMP is still counted separately in the report, because the two
# ways it can escape have different causes, and the utun capture tells them
# apart:
#
#   ICMP outside + also inside the tunnel  -> the engine forwarded it itself.
#       mihomo's ICMP path is a DIRECT outbound (listener/sing_tun/prepare.go),
#       which dials from the physical interface. Fixed by `disable-icmp-
#       forwarding: true` in the tun section, which we render; seeing this again
#       means the config in force predates that (reconnect to apply it).
#
#   ICMP outside, nothing inside          -> the OS never gave it to the tunnel;
#       a routing problem rather than an engine one.
#
# The test targets are public anycast resolvers the engine itself never talks
# to (our DoH upstream is 1.1.1.1, deliberately NOT in the list, so the
# engine's own DNS egress cannot false-positive).
set -euo pipefail

TARGETS=(8.8.8.8 9.9.9.9 208.67.222.222)
DURATION="${1:-0}" # seconds; 0 = until Ctrl-C

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { red "tcpdump needs root: run with sudo"; exit 2; }

# The primary interfaces come from the routing state: with the VPN up the
# default route sits on a utun, and the physical interface still exists
# underneath carrying the encrypted tunnel flow.
NWI="$(scutil --nwi)"
TUN_IF="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
PHY_IF="$(echo "$NWI" | grep -oE 'en[0-9]+' | head -1)"

case "$TUN_IF" in
  utun*) ;;
  *) red "default route is on '${TUN_IF:-?}', not a utun — connect the VPN first"; exit 2 ;;
esac
[ -n "$PHY_IF" ] || { red "could not find the physical interface"; exit 2; }

LEAKS="$(mktemp -t leakcheck)"     # user traffic outside the tunnel: a failure
ICMPS="$(mktemp -t leakcheck-icmp)" # raw ICMP outside the tunnel: reported only
INTUN="$(mktemp -t leakcheck-tun)"  # what did reach the tunnel, for comparison
: > "$LEAKS"; : > "$ICMPS"; : > "$INTUN"

cleanup() {
  trap - INT TERM EXIT
  # The generators and the capture live in subshells; killing a subshell does
  # not signal its children, and an orphaned root tcpdump would outlive the
  # script — so the children go first, then the subshells.
  for p in $(jobs -p); do pkill -TERM -P "$p" 2>/dev/null || true; done
  # shellcheck disable=SC2046
  kill $(jobs -p) 2>/dev/null || true
  wait 2>/dev/null || true
  echo
  bold "── result ──────────────────────────────"
  local leaked icmp tunneled icmp_in_tun
  leaked="$(wc -l < "$LEAKS" | tr -d ' ')"
  icmp="$(wc -l < "$ICMPS" | tr -d ' ')"
  tunneled="$(wc -l < "$INTUN" | tr -d ' ')"
  icmp_in_tun="$(grep -c ICMP "$INTUN" 2>/dev/null || true)"

  echo "test packets seen inside $TUN_IF: $tunneled"

  if [ "$icmp" -gt 0 ]; then
    echo
    red "ICMP LEAK: $icmp packet(s) via $PHY_IF"
    if [ "${icmp_in_tun:-0}" -gt 0 ]; then
      echo "  $icmp_in_tun ICMP packet(s) also went through $TUN_IF: the engine"
      echo "  forwarded them itself with a DIRECT outbound. Expected to be off via"
      echo "  'disable-icmp-forwarding: true' in the tun section — reconnect so the"
      echo "  current config takes effect, and check it is present."
    else
      echo "  Nothing ICMP inside $TUN_IF: the OS never routed it into the tunnel."
    fi
    sed 's/^/  /' "$ICMPS" | head -5
  fi

  echo
  if [ "$leaked" -eq 0 ] && [ "$icmp" -eq 0 ]; then
    green "CLEAN: nothing escaped via $PHY_IF ($tunneled test packets stayed in the tunnel)"
    rm -f "$LEAKS" "$ICMPS" "$INTUN"
    exit 0
  fi
  if [ "$leaked" -gt 0 ]; then
    red "LEAK: $leaked TCP/UDP/DNS packet(s) left via $PHY_IF instead of the tunnel:"
    sed 's/^/  /' "$LEAKS" | head -40
  fi
  rm -f "$LEAKS" "$ICMPS" "$INTUN"
  exit 1
}
trap cleanup INT TERM EXIT

bold "tunnel: $TUN_IF   physical: $PHY_IF   targets: ${TARGETS[*]}"
echo "route to ${TARGETS[0]}: $(route -n get "${TARGETS[0]}" 2>/dev/null | awk '/interface:/{print $2}')"
bold "switch locations/configurations in the app now; Ctrl-C to finish"

# --- traffic generators: a constant stream the tunnel must swallow ---------
for t in "${TARGETS[@]}"; do
  ping -i 0.2 "$t" >/dev/null 2>&1 &
  ( while :; do
      curl -so /dev/null --connect-timeout 1 "https://$t/" || true
      sleep 0.2 # a fast refusal must not turn the probe into a SYN flood
    done ) &
done
# Plain DNS straight at the test resolvers: a deterministic UDP/53 packet per
# iteration that the tunnel's dns-hijack must swallow. dig is the generator of
# record here because it always emits a packet; the system resolver below may
# legitimately decide not to.
( i=0; while :; do
    for t in "${TARGETS[@]}"; do
      dig +time=1 +tries=1 "@$t" "leaktest-$i.example.com" >/dev/null 2>&1 || true
    done
    i=$((i + 1)); sleep 1
  done ) &
# System resolver churn: unique names defeat the cache, so every lookup is a
# real transaction. How mDNSResponder sends it is up to the OS — that is the
# point: with the VPN up, whatever it does must not surface on the physical
# interface as plain DNS to the internet (LAN resolvers are excluded in the
# filter; plaintext to internet resolvers around the tunnel is a DNS leak).
( i=0; while :; do
    dscacheutil -q host -a name "sysres-$i.example.com" >/dev/null 2>&1 || true
    i=$((i + 1)); sleep 1
  done ) &

# --- the watchers -----------------------------------------------------------
TARGET_HOSTS="host ${TARGETS[0]} or host ${TARGETS[1]} or host ${TARGETS[2]}"
# LAN resolvers (the router at 192.168.x.x or its v6 link-local/ULA address)
# are not a leak — only plain DNS escaping to the internet is.
NOT_LOCAL="not dst net 192.168.0.0/16 and not dst net 10.0.0.0/8 and not dst net 172.16.0.0/12 and not dst net 224.0.0.0/4 and not dst net fe80::/10 and not dst net fc00::/7 and not dst net ff00::/8"
PLAIN_DNS="(udp port 53 or tcp port 53 or port 853) and $NOT_LOCAL"

# On the physical side ICMP is separated out: it says something different from
# a TCP/UDP escape (see the header).
( tcpdump -l -n -U -Q out -i "$PHY_IF" "($TARGET_HOSTS or ($PLAIN_DNS)) and not icmp" 2>/dev/null \
    | while IFS= read -r line; do
        echo "$line" >> "$LEAKS"
        red "LEAK  $line"
      done ) &
( tcpdump -l -n -U -Q out -i "$PHY_IF" "($TARGET_HOSTS) and icmp" 2>/dev/null \
    | while IFS= read -r line; do echo "$line" >> "$ICMPS"; done ) &
# And the tunnel side, to tell "the OS bypassed the tunnel" from "both paths
# carried it": whatever shows up here did go through the VPN.
( tcpdump -l -n -U -i "$TUN_IF" "$TARGET_HOSTS or ($PLAIN_DNS)" 2>/dev/null \
    | while IFS= read -r line; do echo "$line" >> "$INTUN"; done ) &

# --- status line: exit IP proves the switch happened; count proves no leak -
START="$(date +%s)"
LAST_IP=""
while :; do
  NOW="$(date +%s)"
  [ "$DURATION" -gt 0 ] && [ $((NOW - START)) -ge "$DURATION" ] && break
  IP="$(curl -s --max-time 2 https://api.ipify.org || echo '?')"
  if [ "$IP" != "$LAST_IP" ] && [ "$IP" != "?" ]; then
    bold "exit IP: $IP"
    LAST_IP="$IP"
  fi
  ROUTE_IF="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
  case "$ROUTE_IF" in
    utun*) ;;
    *) red "WARNING: default route moved to '${ROUTE_IF:-?}' — the session dropped" ;;
  esac
  printf '  %ss elapsed · leaked: %s · icmp outside: %s · inside tunnel: %s\r' \
    "$((NOW - START))" "$(wc -l < "$LEAKS" | tr -d ' ')" \
    "$(wc -l < "$ICMPS" | tr -d ' ')" "$(wc -l < "$INTUN" | tr -d ' ')"
  sleep 3
done
cleanup
