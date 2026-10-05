[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')][string]$Id,
  [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$moduleFile = Join-Path $repoRoot "products/$Id/module.json"
if (-not (Test-Path -LiteralPath $moduleFile -PathType Leaf)) { throw "No product module exists for '$Id'." }
$module = Get-Content -LiteralPath $moduleFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($module.id -ne $Id) { throw "Module directory/id mismatch for '$Id'." }
$buildScript = Join-Path $repoRoot 'scripts/build-qualification-fixture.ps1'
$previewOut = Join-Path ([IO.Path]::GetTempPath()) ("proof-foundry-product-preview-" + $Id + "-" + [Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $previewOut) { throw 'Generated preview folder unexpectedly already exists.' }
# A failed build or server start leaves nothing behind (the catch below). On success the generated site stays for the
# local server, and its path is printed.
$server = $null
try {
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwsh) { throw 'PowerShell 7 (pwsh) is required to run the local preview build.' }
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $pwsh.Source
$startInfo.Arguments = '-NoProfile -File "' + $buildScript + '" -PreviewProductId "' + $Id + '" -OutDir "' + $previewOut + '"'
$startInfo.WorkingDirectory = $repoRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$build = [Diagnostics.Process]::Start($startInfo)
$stdout = $build.StandardOutput.ReadToEnd()
$stderr = $build.StandardError.ReadToEnd()
$build.WaitForExit()
if ($stdout) { Write-Host $stdout.TrimEnd() }
if ($stderr) { Write-Host $stderr.TrimEnd() -ForegroundColor Yellow }
if ($build.ExitCode -ne 0) { throw "Preview build failed with exit code $($build.ExitCode)." }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw 'A local Python runtime is required to serve the generated preview.' }
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start()
$port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()
$serverArgs = '-m http.server ' + $port + ' --bind 127.0.0.1 --directory "' + $previewOut + '"'
$server = Start-Process -FilePath $python.Source -ArgumentList $serverArgs -WindowStyle Hidden -PassThru
$baseUrl = "http://127.0.0.1:$port"
$routeUrl = "$baseUrl/__preview/$Id/"
$ready = $false
for ($attempt=0; $attempt -lt 30; $attempt++) {
  Start-Sleep -Milliseconds 250
  try {
    $response = Invoke-WebRequest -Uri $routeUrl -UseBasicParsing -TimeoutSec 2
    if ($response.StatusCode -eq 200 -and $response.Content -match 'product-preview') { $ready=$true; break }
  } catch {}
}
if (-not $ready) {
  if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
  throw 'Local preview server did not become ready; no deployment was attempted.'
}
} catch {
  if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $previewOut) { Remove-Item -LiteralPath $previewOut -Recurse -Force -ErrorAction SilentlyContinue }
  throw
}
Write-Host "Product preview: $routeUrl"
Write-Host "Homepage placement preview: $baseUrl/__preview/"
Write-Host "Preview catalog: $baseUrl/__preview/software/"
Write-Host "Local server PID: $($server.Id) (stop it with Stop-Process -Id $($server.Id))"
Write-Host "Generated preview files: $previewOut"
Write-Host "When done, stop the server and remove them: Remove-Item -LiteralPath '$previewOut' -Recurse -Force"
if (-not $NoOpen) { Start-Process $routeUrl | Out-Null }
