# summary.sh: what to show about a difference without printing values, and the
# raw-diff and merge editors (spec §5.7). Sourced, not run. Needs common.sh.

NVIM_SAFE="set noswapfile nowritebackup noundofile shadafile=NONE"

# summary_masked NAME LOCAL_FILE VAULT_FILE
summary_masked() {
  case $1 in
    OMP_ENV | NPMRC) summary_keys "$2" "$3" ;;
    *) summary_bytes "$2" "$3" ;;
  esac
}

# join_sorted: sorted stdin lines as "a, b, c".
join_sorted() {
  sort -u | awk '{ printf "%s%s", (NR > 1 ? ", " : ""), $0 } END { if (NR) print "" }'
}

# summary_keys LOCAL VAULT: env-style files. A line is a "KEY=..." line only when
# the text before the first "=" looks like an environment key (letters, digits,
# underscore, at most 64 characters, not starting with a digit) and the line is
# not the padded tail of a base64 block. Only those names are printed. Every other
# changed line, such as the lines of a PEM block or an npmrc registry line, is
# counted and never shown, because there is no telling a name from a secret there.
# Values are never printed.
summary_keys() {
  local tags kind line
  tags=$(awk '
    function keyof(s,   k) { k = s; sub(/=.*/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", k); return k }
    function iskv(s) {
      if (s !~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*=/) return 0
      if (s ~ /^[ \t]*[A-Za-z0-9+\/]+==?[ \t]*$/) return 0
      return length(keyof(s)) <= 64
    }
    FILENAME == ARGV[1] { if (iskv($0)) lk[keyof($0)] = $0; else lo[$0]++; next }
    { if (iskv($0)) vk[keyof($0)] = $0; else vo[$0]++ }
    END {
      for (k in lk) {
        if (!(k in vk)) print "added\t" k
        else if (lk[k] != vk[k]) print "changed\t" k
      }
      for (k in vk) if (!(k in lk)) print "removed\t" k
      n = 0
      for (l in lo) { d = lo[l] - ((l in vo) ? vo[l] : 0); n += (d < 0 ? -d : d) }
      for (l in vo) if (!(l in lo)) n += vo[l]
      print "other\t" n
    }' "$1" "$2")
  for kind in added changed removed; do
    line=$(awk -F'\t' -v k="$kind" '$1 == k { print $2 }' <<<"$tags" | join_sorted)
    if [[ -n $line ]]; then
      echo "  keys $kind (local vs OpenBao): $line"
    fi
  done
  echo "  other changed lines: $(awk -F'\t' '$1 == "other" { print $2 }' <<<"$tags") (values are not shown)"
}

# trailing_newlines FILE
trailing_newlines() {
  jq -Rs 'length - (sub("\n+$"; "") | length)' "$1"
}

# summary_bytes LOCAL VAULT: sizes, trailing newlines, whitespace-only change.
summary_bytes() {
  local ws="no"
  if cmp -s <(tr -d ' \t\r\n' <"$1") <(tr -d ' \t\r\n' <"$2"); then
    ws="yes"
  fi
  echo "  local $(wc -c <"$1" | tr -d ' ') bytes, $(trailing_newlines "$1") trailing newline(s); OpenBao $(wc -c <"$2" | tr -d ' ') bytes, $(trailing_newlines "$2") trailing newline(s); whitespace-only change: $ws (values are not shown)"
}

# show_raw_diff NAME LOCAL_FILE VAULT_FILE: nvim, read-only, no swap/undo/shada.
# The vault copy is a 0600 file in a 0700 directory, removed right after.
show_raw_diff() {
  local d=$WORK/view
  if ! command -v nvim >/dev/null 2>&1; then
    echo "  no raw diff without nvim"
    return 0
  fi
  mkdir -p "$d"
  chmod 700 "$d"
  cp "$3" "$d/$1.vault"
  chmod 600 "$d/$1.vault"
  nvim --clean -n -R -d --cmd "$NVIM_SAFE" -- "$2" "$d/$1.vault" || true
  rm -f "$d/$1.vault"
}
