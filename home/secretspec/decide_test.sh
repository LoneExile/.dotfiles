#!/usr/bin/env bash
# Table tests for decide() (spec §5.5). Pure: no vault, no files.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1
# shellcheck source=decide.sh
. "$ROOT/decide.sh" || exit 1

# Hook stubs. H_CTS lists "VERSION=CREATED_TIME" of retained versions; H_LIVE
# lists "VERSION=SHA" of retained versions whose bytes still exist.
H_CTS=""
H_LIVE=""
H_CT_CALLS=0
H_STALE_CALLS=0
d_ct_at() {
  local p
  H_CT_CALLS=$((H_CT_CALLS + 1))
  D_HOOK_CT=""
  for p in $H_CTS; do
    if [[ ${p%%=*} == "$1" ]]; then D_HOOK_CT=${p#*=}; fi
  done
  return 0
}
d_stale() {
  local p v
  H_STALE_CALLS=$((H_STALE_CALLS + 1))
  for p in $H_LIVE; do
    v=${p%%=*}
    if [[ $v -gt $1 && ${p#*=} == "$D_LSHA" ]]; then return 0; fi
  done
  return 1
}

# inp CLASS LOCAL LSHA CUR CT VSHA BV BSHA BCT: set every input at once.
inp() {
  D_CLASS=$1 D_LOCAL=$2 D_LSHA=$3 D_CUR=$4 D_CT=$5 D_VSHA=$6 D_BV=$7 D_BSHA=$8 D_BCT=$9
  H_CTS="" H_LIVE="" H_CT_CALLS=0 H_STALE_CALLS=0
}
# expect LABEL ROW STATE [NOTE]
expect() {
  decide
  assert_eq "$1" "$D_ROW/$D_STATE/$D_NOTE" "$2/$3/${4:-}"
}

test_transport_rows_win_over_everything() {
  inp soft regular A 5 t5 B 3 A t3
  expect "1a soft error" 1a offline
  inp hard other A 5 t5 B 3 A t3
  expect "1b hard error beats a blocked path" 1b auth-failed
  inp missing absent "" 0 "" "" 3 A t3
  expect "2 vault missing with a base" 2 vault-missing
  inp missing regular A 1 t1 "" "" "" ""
  expect "2 vault missing, local present" 2 vault-missing
}

test_local_state_rows() {
  inp ok other A 2 t2 B 2 B t2
  expect "3 symlink/directory/special file" 3 blocked
  inp ok absent "" 2 t2 B 2 B t2
  expect "4 no local file, with base" 4 missing-local
  inp ok absent "" 2 t2 B "" "" ""
  expect "4 no local file, no base" 4 missing-local
  inp ok regular B 2 t2 B 2 B t2
  expect "5 in sync" 5 in-sync
  inp ok regular B 2 t2 B "" "" ""
  expect "5 in sync without a base" 5 in-sync
  assert_eq "in-sync reads no metadata" "$H_CT_CALLS/$H_STALE_CALLS" 0/0
  inp ok regular B 1 t1 B 4 B t4
  expect "5 beats 6: equal bytes win even when the vault was rewound" 5 in-sync
}

test_row_6_rewound() {
  inp ok regular A 2 t2 B 5 A t5
  expect "6 vault version below the base" 6 rewound
  inp ok regular A 5 t5new B 5 A t5old
  expect "6 recreated history at the same version (M1)" 6 rewound
  inp ok regular S 2 tY T 2 S tX
  expect "6 M1: unchanged local file, wiped and recreated vault" 6 rewound
  inp ok regular A 7 t7 B 5 A t5old
  H_CTS="5=t5new 6=t6 7=t7"
  expect "6 recreated history, base version retained with another epoch" 6 rewound
  inp ok regular A 7 t7 B 5 A t5
  H_CTS="5=t5 6=t6 7=t7"
  expect "not rewound: base version retained with the same epoch" 8 behind
  inp ok regular A 7 t7 B 5 A t5
  H_CTS="6=t6 7=t7"
  expect "not rewound: base version pruned, only a lower CUR counts" 8 behind
}

test_row_7_bad_record_is_ignored() {
  inp ok regular A 5 t5 B 5 C t5
  H_LIVE="5=B 4=A"
  expect "7 then 9: bad record, local equals an older live version" 9 stale bad-record
  inp ok regular A 5 t5 B 5 C t5
  H_LIVE="5=B"
  expect "7 then 12: bad record, nothing matches" 12 unknown bad-record
  inp ok regular A 5 t5 B 5 B t5
  H_LIVE="5=B"
  expect "no bad record when the record matches the vault" 10 ahead
}

test_row_8_behind() {
  inp ok regular A 6 t6 B 5 A t5
  H_CTS="5=t5"
  expect "8 vault moved on, local untouched" 8 behind
  inp ok regular A 6 t6 B 5 A t5
  H_CTS="5=t5"
  H_LIVE="6=B 5=A"
  expect "8 wins over 9" 8 behind
  # Here a live version newer than the base (v5) really does hold the local
  # bytes, so row 9 would match too; row 8 must still win because the local
  # file equals the base.
  inp ok regular A 6 t6 B 4 A t4
  H_CTS="4=t4"
  H_LIVE="6=B 5=A 4=A"
  expect "8 wins over 9 even when row 9 would match" 8 behind
  assert_eq "row 9's lookup was never needed" "$H_STALE_CALLS" 0
}

test_row_9_stale() {
  inp ok regular A 6 t6 B 3 Z t3
  H_CTS="3=t3"
  H_LIVE="6=B 5=A 4=Q 3=Z"
  expect "9 local equals a live version newer than the base" 9 stale
  inp ok regular A 6 t6 B "" "" ""
  H_LIVE="6=B 2=A"
  expect "9 without a base any live version counts" 9 stale
}

test_b1_an_edit_back_to_an_older_value_is_an_edit() {
  # v1=A, v2=B, base v2, the user edits the file back to A.
  inp ok regular A 2 t2 B 2 B t2
  H_LIVE="2=B 1=A"
  expect "B1 ahead, not an auto-revert" 10 ahead
  assert_eq "B1 reads no versions" "$H_STALE_CALLS" 0
  # The same bytes, but the vault moved to v3 meanwhile: diverged, never stale.
  inp ok regular A 3 t3 C 2 B t2
  H_CTS="2=t2"
  H_LIVE="3=C 2=B 1=A"
  expect "B1 variant: older than the base cannot be stale" 11 diverged
}

test_rows_10_11_12() {
  inp ok regular E 5 t5 B 5 B t5
  expect "10 local edited, vault untouched since the base" 10 ahead
  inp ok regular E 6 t6 C 5 B t5
  H_CTS="5=t5"
  H_LIVE="6=C 5=B"
  expect "11 both sides changed" 11 diverged
  inp ok regular E 6 t6 C "" "" ""
  H_LIVE="6=C"
  expect "12 no record, bytes differ" 12 unknown
}

tl_init_pure
tl_run_all
tl_done
