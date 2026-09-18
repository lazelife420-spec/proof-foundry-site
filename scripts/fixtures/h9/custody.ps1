# Repository-custody helpers. Raw hashes remain evidence; CRLF/LF alone may differ for UTF-8 text.
function Get-H9Sha256([byte[]]$Bytes) {
  return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}
function Get-H9LfBytes([byte[]]$Bytes) {
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  return $utf8.GetBytes($utf8.GetString($Bytes).Replace("`r`n", "`n"))
}
function Test-H9Custody([string]$Root, $Entry) {
  $path = Join-Path $Root $Entry.path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
  $bytes = [IO.File]::ReadAllBytes($path)
  $expected = if ($Entry.migration) { $Entry.migration } else { $Entry }
  if ($Entry.comparison -eq 'binary') { return (Get-H9Sha256 $bytes) -ceq $expected.sha256 }
  if ($Entry.comparison -ne 'utf8-lf') { throw "Unknown H9 custody comparison: $($Entry.comparison)" }
  return (Get-H9Sha256 (Get-H9LfBytes $bytes)) -ceq $expected.lfSha256
}
