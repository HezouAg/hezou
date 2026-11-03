$hezouSite = if ($env:HEZOU_SITE) { $env:HEZOU_SITE.TrimEnd('/') } else { 'https://hezou.app' }
$hezouTarget = if ($env:HEZOU_TARGET) { $env:HEZOU_TARGET } else { 'claude' }
if ($hezouTarget -ne 'claude' -and $hezouTarget -ne 'codex') {
  throw "Unknown target `"$hezouTarget`": use claude or codex"
}

$hezouRoots = @()
$hezouGit = Get-Command git.exe -ErrorAction SilentlyContinue
if ($hezouGit) { $hezouRoots += Split-Path (Split-Path $hezouGit.Source) }
foreach ($hezouDir in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) {
  if ($hezouDir) { $hezouRoots += Join-Path $hezouDir 'Git' }
}
if ($env:LOCALAPPDATA) { $hezouRoots += Join-Path $env:LOCALAPPDATA 'Programs\Git' }
$hezouBash = $hezouRoots | ForEach-Object { Join-Path $_ 'bin\bash.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $hezouBash) {
  $hezouAfter = if ($hezouTarget -eq 'claude') { 'then restart Claude Code and run this installer again' } else { 'then run this installer again' }
  throw "HEZOU on Windows needs Git for Windows, and it was not found, so nothing was installed. For the AI agent: ask the user, and on yes run: winget install --id Git.Git -e --source winget (or send them to https://git-scm.com/download/win), $hezouAfter."
}

& $hezouBash -c "set -o pipefail; curl -fsSL '$hezouSite/install.sh' | bash -s $hezouTarget"
if ($LASTEXITCODE -ne 0) {
  throw "The HEZOU installer stopped with code $LASTEXITCODE. Nothing above was changed unless it says so; check the network (Codex needs network access allowed) and run it again."
}

if ($hezouTarget -eq 'claude') {
  Write-Output 'If Claude Code was started before Git for Windows was installed, restart it so the agents get their Bash tool.'
}
