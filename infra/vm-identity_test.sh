#!/usr/bin/env bash
# Tests for infra/vm-identity.sh (identity_from_vms, identity_validate, identity_write). Fixtures only:
# RFC 5737 addresses, a locally administered MAC, an invented name.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

NAME=testvm-alpha
MAC=02:00:5E:10:00:01
CIDR=203.0.113.10/24
GW=203.0.113.1
NL=$'\n'

# run FUNCTION ARGS...: run a library function as vm-install.sh does (umask 077, die exits the
# subshell), print its exit status. The umask makes the library's chmod calls load-bearing: without
# them the files would not be readable by networkd's unprivileged user.
run() {
  (
    umask 077
    die() {
      printf 'vm-install: %s\n' "$1" >&2
      exit 1
    }
    # shellcheck source=vm-identity.sh
    . "$ROOT/infra/vm-identity.sh"
    "$@"
  ) >"$T/out" 2>"$T/err"
  echo $?
}
write() { run identity_write "$T/tree" "$@"; }

test_writes_hostname_and_static_network() {
  assert_rc "write" "$(write $NAME $MAC $CIDR $GW 198.51.100.53 198.51.100.54)" 0
  assert_eq "hostname content" "$NAME" "$(cat "$T/tree/etc/hostname")"
  assert_eq "hostname mode" 644 "$(tl_mode "$T/tree/etc/hostname")"
  assert_eq "network content" "[Match]
MACAddress=$MAC

[Network]
Address=$CIDR
Gateway=$GW
DNS=198.51.100.53
DNS=198.51.100.54" "$(cat "$T/tree/etc/systemd/network/10-static.network")"
  assert_eq "network mode" 644 "$(tl_mode "$T/tree/etc/systemd/network/10-static.network")"
}

test_directories_are_traversable() {
  assert_rc "write" "$(write $NAME $MAC $CIDR $GW 198.51.100.53)" 0
  assert_eq "etc mode" 755 "$(tl_mode "$T/tree/etc")"
  assert_eq "systemd mode" 755 "$(tl_mode "$T/tree/etc/systemd")"
  assert_eq "network dir mode" 755 "$(tl_mode "$T/tree/etc/systemd/network")"
  assert_eq "tree root mode" 755 "$(tl_mode "$T/tree")"
}

test_no_resolver_means_no_dns_line() {
  assert_rc "write" "$(write $NAME $MAC $CIDR $GW)" 0
  assert_lacks "no DNS line" "$T/tree/etc/systemd/network/10-static.network" "DNS="
  assert_has "has the gateway" "$T/tree/etc/systemd/network/10-static.network" "Gateway=$GW"
}

test_lowercase_mac_and_ipv6_resolver_are_accepted() {
  assert_rc "write" "$(write $NAME 02:00:5e:10:00:01 $CIDR $GW 2001:db8::53 ::1)" 0
  assert_has "ipv6 dns" "$T/tree/etc/systemd/network/10-static.network" "DNS=2001:db8::53"
  assert_has "ipv6 loopback dns" "$T/tree/etc/systemd/network/10-static.network" "DNS=::1"
}

test_name_length_limits() {
  local n63 n64
  n63=a$(printf 'b%.0s' $(seq 1 61))c
  n64=a$(printf 'b%.0s' $(seq 1 62))c
  assert_rc "63 characters" "$(write "$n63" $MAC $CIDR $GW)" 0
  assert_rc "4 characters" "$(write abcd $MAC $CIDR $GW)" 0
  reject "name" "$n64" "$n64" $MAC $CIDR $GW
}

# reject FIELD SECRET ARGS...: the write must fail, name the field, create nothing, and not echo
# the value. (Not named `bad`: testlib.sh owns that name.)
reject() {
  local field=$1 secret=$2
  shift 2
  rm -rf "$T/tree"
  assert_rc "$field rejected" "$(write "$@")" 1
  assert_has "$field named" "$T/err" "$field"
  assert_lacks "$field value not echoed (stderr)" "$T/err" "$secret"
  assert_lacks "$field value not echoed (stdout)" "$T/out" "$secret"
  assert_absent "$field: nothing written" "$T/tree"
}

test_bad_name() {
  reject "name" "Bad_Name" "Bad_Name" $MAC $CIDR $GW
  reject "name" "abc" "abc" $MAC $CIDR $GW
  reject "name" "-leadinghyphen" "-leadinghyphen" $MAC $CIDR $GW
  reject "name" "injected" "testvm-alpha${NL}injected" $MAC $CIDR $GW
  reject "name" "injected" "injected${NL}testvm-alpha" $MAC $CIDR $GW
  reject "name" "emptyname" "" $MAC $CIDR $GW
}

test_bad_mac() {
  reject "mac" "02:00:5E:10:00" $NAME 02:00:5E:10:00 $CIDR $GW
  reject "mac" "02-00-5E-10-00-01" $NAME 02-00-5E-10-00-01 $CIDR $GW
  reject "mac" "DNS=" $NAME "$MAC${NL}DNS=" $CIDR $GW
  reject "mac" "DNS=" $NAME "DNS=${NL}$MAC" $CIDR $GW
  reject "mac" "02:00:5E:10:00:01:" $NAME "$MAC:" $CIDR $GW
  reject "mac" "emptymac" $NAME "" $CIDR $GW
}

test_bad_cidr() {
  reject "ipv4_cidr" "203.0.113.10/33" $NAME $MAC 203.0.113.10/33 $GW
  reject "ipv4_cidr" "203.0.113.256/24" $NAME $MAC 203.0.113.256/24 $GW
  reject "ipv4_cidr" "203.0.113.10" $NAME $MAC 203.0.113.10 $GW
  reject "ipv4_cidr" "Gateway=" $NAME $MAC "$CIDR${NL}Gateway=" $GW
  reject "ipv4_cidr" "Gateway=" $NAME $MAC "Gateway=${NL}$CIDR" $GW
  reject "ipv4_cidr" "x203.0.113.10/24" $NAME $MAC "x$CIDR" $GW
  reject "ipv4_cidr" "emptycidr" $NAME $MAC "" $GW
}

test_bad_gateway() {
  reject "gateway" "203.0.113.999" $NAME $MAC $CIDR 203.0.113.999
  reject "gateway" "gw.example" $NAME $MAC $CIDR gw.example
  reject "gateway" "Address=" $NAME $MAC $CIDR "$GW${NL}Address="
  reject "gateway" "Address=" $NAME $MAC $CIDR "Address=${NL}$GW"
  reject "gateway" "x203.0.113.1" $NAME $MAC $CIDR "x$GW"
  reject "gateway" "emptygw" $NAME $MAC $CIDR ""
}

test_bad_resolver() {
  reject "resolver" "198.51.100.53 evil" $NAME $MAC $CIDR $GW "198.51.100.53 evil"
  reject "resolver" "Address=" $NAME $MAC $CIDR $GW "198.51.100.53${NL}Address="
  reject "resolver" "Address=" $NAME $MAC $CIDR $GW "Address=${NL}198.51.100.53"
  reject "resolver" "dns.example" $NAME $MAC $CIDR $GW dns.example
  reject "resolver" "abc" $NAME $MAC $CIDR $GW abc
  reject "resolver" "..." $NAME $MAC $CIDR $GW ...
  reject "resolver" "emptydns" $NAME $MAC $CIDR $GW ""
  reject "resolver" "198.51.100.300" $NAME $MAC $CIDR $GW 198.51.100.300
}

test_validate_alone_writes_nothing() {
  assert_rc "valid" "$(run identity_validate $NAME $MAC $CIDR $GW 198.51.100.53)" 0
  assert_absent "no tree" "$T/tree"
}

# parse JSON NAME: run identity_from_vms and print its results on one line.
parse() {
  (
    umask 077
    die() {
      printf 'vm-install: %s\n' "$1" >&2
      exit 1
    }
    # shellcheck source=vm-identity.sh
    . "$ROOT/infra/vm-identity.sh"
    identity_from_vms "$1" "$2"
    printf '%s|%s|%s|%s' "$id_mac" "$id_cidr" "$id_gateway" "${#id_dns[@]}"
    for d in ${id_dns[@]+"${id_dns[@]}"}; do printf '|%s' "$d"; done
  ) >"$T/out" 2>"$T/err"
  echo $?
}
vms() { # vms DNS_JSON [EXTRA]: one entry
  printf '{"%s":{"node":"n1","vmid":901,"mac":"%s","ipv4_cidr":"%s","gateway":"%s"%s}}' "$NAME" "$MAC" "$CIDR" "$GW" "${1:+,\"dns\":$1}"
}

test_from_vms_reads_the_entry() {
  assert_rc "two resolvers" "$(parse "$(vms '["198.51.100.53","198.51.100.54"]')" $NAME)" 0
  assert_eq "fields" "$MAC|$CIDR|$GW|2|198.51.100.53|198.51.100.54" "$(cat "$T/out")"
  assert_rc "empty list" "$(parse "$(vms '[]')" $NAME)" 0
  assert_eq "no resolver" "$MAC|$CIDR|$GW|0" "$(cat "$T/out")"
  assert_rc "dns key missing" "$(parse "$(vms)" $NAME)" 0
  assert_eq "no resolver either" "$MAC|$CIDR|$GW|0" "$(cat "$T/out")"
}

test_from_vms_picks_the_named_entry_only() {
  local two
  two='{"other-vm":{"mac":"02:00:5E:10:00:09","ipv4_cidr":"203.0.113.99/24","gateway":"203.0.113.1","dns":["198.51.100.99"]},"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53"]}}'
  assert_rc "named entry" "$(parse "$two" $NAME)" 0
  assert_eq "its fields" "$MAC|$CIDR|$GW|1|198.51.100.53" "$(cat "$T/out")"
}

test_from_vms_unknown_name_and_bad_json() {
  assert_rc "unknown name" "$(parse "$(vms '[]')" nobody-here)" 1
  assert_has "says no VM named" "$T/err" "no VM named"
  assert_rc "not json" "$(parse 'not json' $NAME)" 1
  assert_has "says shape" "$T/err" "unexpected shape"
  assert_rc "array" "$(parse '[1]' $NAME)" 1
  assert_has "array says shape" "$T/err" "unexpected shape"
}

test_from_vms_rejects_odd_field_shapes() {
  local j
  for j in \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":false}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":null}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":"198.51.100.53"}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":[1]}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":[null]}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53",""]}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53|198.51.100.54"]}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1\nDNS=198.51.100.53"}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53\nAddress=1"]}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01|x","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1"}}' \
    '{"testvm-alpha":{"mac":7,"ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1"}}' \
    '{"testvm-alpha":{"ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1"}}' \
    '{"testvm-alpha":{"mac":"02:00:5E:10:00:01","gateway":"203.0.113.1"}}'; do
    assert_rc "odd shape: ${j:0:90}" "$(parse "$j" $NAME)" 1
    assert_has "says shape" "$T/err" "unexpected shape"
    assert_lacks "no value in the message" "$T/err" "198.51.100.53"
  done
}

tl_init_pure
tl_run_all
tl_done
