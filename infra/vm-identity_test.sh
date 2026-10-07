#!/usr/bin/env bash
# Tests for infra/vm-identity.sh (identity_validate, identity_write). Fixtures only:
# RFC 5737 addresses, a locally administered MAC, an invented name.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

NAME=testvm-alpha
MAC=02:00:5E:10:00:01
CIDR=203.0.113.10/24
GW=203.0.113.1

# run FUNCTION ARGS...: run a library function as vm-install.sh does (die exits the subshell), print its exit status.
run() {
  (
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
}

test_no_resolver_means_no_dns_line() {
  assert_rc "write" "$(write $NAME $MAC $CIDR $GW)" 0
  assert_lacks "no DNS line" "$T/tree/etc/systemd/network/10-static.network" "DNS="
  assert_has "has the gateway" "$T/tree/etc/systemd/network/10-static.network" "Gateway=$GW"
}

test_lowercase_mac_and_ipv6_resolver_are_accepted() {
  assert_rc "write" "$(write $NAME 02:00:5e:10:00:01 $CIDR $GW 2001:db8::53)" 0
  assert_has "ipv6 dns" "$T/tree/etc/systemd/network/10-static.network" "DNS=2001:db8::53"
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
  reject "name" "injected" "testvm-alpha
injected" $MAC $CIDR $GW
}

test_bad_mac() {
  reject "mac" "02:00:5E:10:00" $NAME 02:00:5E:10:00 $CIDR $GW
  reject "mac" "02-00-5E-10-00-01" $NAME 02-00-5E-10-00-01 $CIDR $GW
}

test_bad_cidr() {
  reject "ipv4_cidr" "203.0.113.10/33" $NAME $MAC 203.0.113.10/33 $GW
  reject "ipv4_cidr" "203.0.113.256/24" $NAME $MAC 203.0.113.256/24 $GW
  reject "ipv4_cidr" "203.0.113.10" $NAME $MAC 203.0.113.10 $GW
  reject "ipv4_cidr" "Gateway=" $NAME $MAC "203.0.113.10/24
Gateway=" $GW
}

test_bad_gateway() {
  reject "gateway" "203.0.113.999" $NAME $MAC $CIDR 203.0.113.999
  reject "gateway" "gw.example" $NAME $MAC $CIDR gw.example
}

test_bad_resolver() {
  reject "resolver" "198.51.100.53 evil" $NAME $MAC $CIDR $GW "198.51.100.53 evil"
  reject "resolver" "Address=" $NAME $MAC $CIDR $GW "198.51.100.53
Address="
  reject "resolver" "dns.example" $NAME $MAC $CIDR $GW dns.example
}

test_validate_alone_writes_nothing() {
  assert_rc "valid" "$(run identity_validate $NAME $MAC $CIDR $GW 198.51.100.53)" 0
  assert_absent "no tree" "$T/tree"
}

tl_init_pure
tl_run_all
tl_done
