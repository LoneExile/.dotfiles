# apply.ps1 -Bundle DIR [-Check]: the Windows half of win-sync (hosts/windows/win-sync.sh). The Mac renders the
# bundle (hosts/windows/win-render.py), copies it here and runs this script over SSH as the user it sets up.
# Windows PowerShell 5.1, ASCII only (5.1 reads a script without a byte order mark as ANSI).
#
# In order, each step changing only what differs and printing one line per item (ok, changed, kept, drift, error):
#   winget   install the missing packages of winget.txt (never upgrades or removes one)
#   files    install files.tsv: SRC (in the bundle) -> DEST (~ is %USERPROFILE%, %APPDATA% is %APPDATA%), the
#            way home/linux/writable-copy.sh does on the VMs: a missing DEST is installed; a DEST edited here
#            stays while the repo copy is the one installed last time (a stamp in %LOCALAPPDATA%\dotfiles
#            records that); when the repo copy changes, an edited DEST is kept as DEST.dotfiles-backup and
#            replaced. Mode secret also makes DEST (and its backup) readable by this user and SYSTEM only.
#   tern     add the missing lines of tern-hosts.txt to Tern's host list, and pin the host keys of
#            tern-pins.txt (tern remote trust) that its known_hosts does not hold yet
#   skills   mirror each skill of skills.txt into ~/.omp/agent/skills/<name> (robocopy /MIR); nothing else in
#            that directory is touched
#   plugins  bun install --frozen-lockfile in ~/.omp/plugins when the manifests' hash (plugins.sha256) differs
#            from the last install's, or node_modules is missing
# -Check changes nothing and prints drift for what the sync would change.
# Exit 0, or 1 on an error, and with -Check on any drift.
param(
  [Parameter(Mandatory = $true)][string]$Bundle,
  [switch]$Check
)
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$script:counts = @{ ok = 0; changed = 0; kept = 0; drift = 0; error = 0 }
$state = Join-Path $env:LOCALAPPDATA 'dotfiles'
$me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$system = 'S-1-5-18'

function Say([string]$kind, [string]$msg) {
  Write-Output ('{0}: {1}' -f $kind, $msg)
  $script:counts[$kind]++
}

# Run a native program: its exit code and its output (stdout and stderr) as text. PowerShell 5.1 turns a native
# program's stderr into error records, which 'Stop' throws on, so this runs under 'Continue'.
function Run-Native([string]$exe, [string[]]$argv) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & $exe @argv 2>&1 | ForEach-Object { "$_" } | Out-String
    return @{ Code = $LASTEXITCODE; Output = $out.Trim() }
  } finally {
    $ErrorActionPreference = $old
  }
}

function Tail([string]$text) {
  $lines = @($text -split "`r?`n" | Where-Object { $_.Trim() })
  return ($lines | Select-Object -Last 3) -join ' / '
}

function Bundle-Lines([string]$file) {
  return @(Get-Content -LiteralPath (Join-Path $Bundle $file) | Where-Object { $_ })
}

function Hash([string]$path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
}

function Expand-Dest([string]$spec) {
  if ($spec.StartsWith('~/')) { return Join-Path $env:USERPROFILE ($spec.Substring(2) -replace '/', '\') }
  if ($spec.StartsWith('%APPDATA%/')) { return Join-Path $env:APPDATA ($spec.Substring(10) -replace '/', '\') }
  throw "unexpected destination $spec"
}

function Read-Stamp([string]$path) {
  if (Test-Path -LiteralPath $path) { return ([IO.File]::ReadAllText($path)).Trim() }
  return ''
}

function Write-Stamp([string]$path, [string]$value) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
  [IO.File]::WriteAllText($path, $value)
}

# True when only this user and SYSTEM have access to PATH, and it inherits nothing.
function Test-Locked([string]$path) {
  $acl = Get-Acl -LiteralPath $path
  if (-not $acl.AreAccessRulesProtected) { return $false }
  foreach ($rule in $acl.Access) {
    $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
    if ($sid -ne $me -and $sid -ne $system) { return $false }
  }
  return $true
}

function Lock-File([string]$path) {
  $r = Run-Native 'icacls.exe' @($path, '/setowner', "*$me")
  if ($r.Code -ne 0) { throw "icacls /setowner failed on ${path}: $(Tail $r.Output)" }
  $r = Run-Native 'icacls.exe' @($path, '/inheritance:r', '/grant:r', "*${me}:(F)", '/grant:r', "*${system}:(F)")
  if ($r.Code -ne 0) { throw "icacls failed on ${path}: $(Tail $r.Output)" }
}

function Sync-Winget {
  foreach ($id in Bundle-Lines 'winget.txt') {
    $r = Run-Native 'winget.exe' @('list', '--id', $id, '--exact', '--accept-source-agreements', '--disable-interactivity')
    if ($r.Code -eq 0) { Say 'ok' "winget: $id"; continue }
    if ($Check) { Say 'drift' "winget: $id is not installed"; continue }
    $r = Run-Native 'winget.exe' @('install', '--id', $id, '--exact', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($r.Code -ne 0) { Say 'error' "winget: installing $id failed (exit $($r.Code)): $(Tail $r.Output)"; continue }
    Say 'changed' "winget: $id installed"
  }
  # The installers add to PATH in the registry only: read it again, so that the steps below find bun and node.
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-File([string]$mode, [string]$src, [string]$dest) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
  Copy-Item -LiteralPath $src -Destination $dest -Force
  if ($mode -eq 'secret') { Lock-File $dest }
}

function Sync-File([string]$mode, [string]$srcRel, [string]$spec) {
  $src = Join-Path $Bundle ($srcRel -replace '/', '\')
  $dest = Expand-Dest $spec
  $stamp = Join-Path $state ('writable-copy\' + ($dest -replace '[:\\/ ]', '_'))
  $want = Hash $src
  $recorded = Read-Stamp $stamp
  $have = ''
  if (Test-Path -LiteralPath $dest -PathType Leaf) { $have = Hash $dest }
  $leaf = Split-Path -Leaf $dest

  if ($have -eq $want) {
    if (-not $Check -and $recorded -ne $want) { Write-Stamp $stamp $want }
  } elseif ($have -eq '') {
    if ($Check) { Say 'drift' "$spec is missing"; return }
    Install-File $mode $src $dest
    Write-Stamp $stamp $want
    Say 'changed' "$spec installed"
    return
  } elseif ($recorded -eq $want) {
    Say 'kept' "$spec has a local edit, and the repo copy is the one installed last time: the edit stays"
  } else {
    if ($Check) { Say 'drift' "$spec differs from the repo copy"; return }
    if ($have -ne $recorded) {
      Copy-Item -LiteralPath $dest -Destination "$dest.dotfiles-backup" -Force
      if ($mode -eq 'secret') { Lock-File "$dest.dotfiles-backup" }
      Install-File $mode $src $dest
      Write-Stamp $stamp $want
      Say 'changed' "$spec replaced; the file it held is kept as $leaf.dotfiles-backup"
    } else {
      Install-File $mode $src $dest
      Write-Stamp $stamp $want
      Say 'changed' "$spec updated"
    }
    return
  }

  if ($mode -eq 'secret' -and -not (Test-Locked $dest)) {
    if ($Check) { Say 'drift' "$spec is readable by more than this user and SYSTEM"; return }
    Lock-File $dest
    Say 'changed' "$spec made readable by this user and SYSTEM only"
    return
  }
  if ($have -eq $want) { Say 'ok' $spec }
}

function Sync-Files {
  foreach ($row in Bundle-Lines 'files.tsv') {
    $mode, $src, $spec = $row -split "`t"
    try { Sync-File $mode $src $spec } catch { Say 'error' "${spec}: $($_.Exception.Message)" }
  }
}

function Sync-Tern {
  $dir = Join-Path $env:APPDATA 'Tern'
  $tern = Join-Path $env:LOCALAPPDATA 'Programs\Tern\tern.com'
  if (-not (Test-Path -LiteralPath $tern)) { Say 'error' "Tern is not installed ($tern is missing)"; return }

  $file = Join-Path $dir 'hosts'
  $want = Bundle-Lines 'tern-hosts.txt'
  $have = @()
  if (Test-Path -LiteralPath $file) { $have = @(Get-Content -LiteralPath $file) }
  $missing = @($want | Where-Object { $have -cnotcontains $_ })
  if ($missing.Count -eq 0) {
    Say 'ok' "Tern hosts: $($want.Count) listed"
  } elseif ($Check) {
    foreach ($m in $missing) { Say 'drift' "Tern hosts: $(($m -split "`t")[0]) is not listed" }
  } else {
    $text = ''
    if (-not (Test-Path -LiteralPath $file)) {
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
      $text = "# Remote hosts Tern connects to: [user@]host[:port] or [user@]<endpoint id>, one per line,`n# optionally followed by a tab and the name Tern shows for it.`n"
    } elseif ((Get-Item -LiteralPath $file).Length -gt 0 -and -not ([IO.File]::ReadAllText($file).EndsWith("`n"))) {
      $text = "`n"
    }
    [IO.File]::AppendAllText($file, $text + (($missing -join "`n") + "`n"))
    foreach ($m in $missing) { Say 'changed' "Tern hosts: $(($m -split "`t")[0]) added" }
  }

  $known = Join-Path $dir 'known_hosts'
  $pinned = @()
  if (Test-Path -LiteralPath $known) { $pinned = @(Get-Content -LiteralPath $known) }
  foreach ($line in Bundle-Lines 'tern-pins.txt') {
    $hostPort, $fingerprint = $line -split ' ', 2
    if ($pinned -ccontains $line) { Say 'ok' "Tern host key of $hostPort pinned"; continue }
    if ($Check) { Say 'drift' "Tern host key of $hostPort is not pinned"; continue }
    $r = Run-Native $tern @('remote', 'trust', $hostPort, $fingerprint)
    if ($r.Code -ne 0) { Say 'error' "tern remote trust $hostPort failed: $(Tail $r.Output)"; continue }
    Say 'changed' "Tern host key of $hostPort pinned"
  }
}

function Sync-Skills {
  $root = Join-Path $env:USERPROFILE '.omp\agent\skills'
  $count = 0
  $differ = 0
  foreach ($name in Bundle-Lines 'skills.txt') {
    $argv = @((Join-Path $Bundle "skills\$name"), (Join-Path $root $name), '/MIR', '/R:1', '/W:1', '/NJH', '/NJS', '/NDL', '/NFL', '/NP')
    if ($Check) { $argv += '/L' }
    $r = Run-Native 'robocopy.exe' $argv
    if ($r.Code -ge 8) { Say 'error' "skill ${name}: robocopy failed (exit $($r.Code)): $(Tail $r.Output)"; continue }
    $count++
    if ($r.Code -gt 0) {
      $differ++
      if ($Check) { Say 'drift' "skill $name differs" } else { Say 'changed' "skill $name mirrored" }
    }
  }
  if ($differ -eq 0) { Say 'ok' "skills: $count mirrored into ~/.omp/agent/skills" }
}

function Sync-Plugins {
  $dir = Join-Path $env:USERPROFILE '.omp\plugins'
  $want = ([IO.File]::ReadAllText((Join-Path $Bundle 'plugins.sha256'))).Trim()
  $stamp = Join-Path $state 'omp-plugins.stamp'
  $modules = Test-Path -LiteralPath (Join-Path $dir 'node_modules')
  if ((Read-Stamp $stamp) -eq $want -and $modules) { Say 'ok' 'omp plugins installed'; return }
  if ($Check) { Say 'drift' 'omp plugins: the manifests changed since the last install, or node_modules is missing'; return }
  $bun = Get-Command bun.exe -ErrorAction SilentlyContinue
  if (-not $bun) { Say 'error' 'omp plugins: bun is not on PATH (winget Oven-sh.Bun)'; return }
  Push-Location $dir
  try { $r = Run-Native $bun.Source @('install', '--frozen-lockfile', '--cwd', $dir) } finally { Pop-Location }
  if ($r.Code -ne 0) { Say 'error' "omp plugins: bun install failed (exit $($r.Code)): $(Tail $r.Output)"; return }
  Write-Stamp $stamp $want
  Say 'changed' 'omp plugins installed (bun install --frozen-lockfile)'
}

foreach ($step in 'Sync-Winget', 'Sync-Files', 'Sync-Tern', 'Sync-Skills', 'Sync-Plugins') {
  try { & $step } catch { Say 'error' "${step}: $($_.Exception.Message)" }
}
$c = $script:counts
Write-Output ('win-sync: {0} ok, {1} changed, {2} kept, {3} drift, {4} errors' -f $c.ok, $c.changed, $c.kept, $c.drift, $c.error)
if ($c.error -gt 0 -or ($Check -and $c.drift -gt 0)) { exit 1 }
exit 0
