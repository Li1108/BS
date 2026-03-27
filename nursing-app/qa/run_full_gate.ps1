param(
  [switch]$SkipFlutter,
  [switch]$SkipFrontend,
  [switch]$SkipBackend
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host "`n===== $Name =====" -ForegroundColor Cyan
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  & $Action
  $sw.Stop()
  Write-Host "[PASS] $Name (${sw.Elapsed})" -ForegroundColor Green
}

$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend-springboot'
$frontend = Join-Path $root 'admin-vue3\vue-project'
$flutter = Join-Path $root 'android-flutter\nursing_app'

if (-not $SkipBackend) {
  Invoke-Step 'Backend regression + stress + fault injection (mvn test)' {
    Push-Location $backend
    try {
      mvn test -q
      if ($LASTEXITCODE -ne 0) {
        throw "Backend tests failed with exit code $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }
  }
}

if (-not $SkipFrontend) {
  Invoke-Step 'Admin frontend regression (vitest)' {
    Push-Location $frontend
    try {
      npm run test -- --run
      if ($LASTEXITCODE -ne 0) {
        throw "Frontend tests failed with exit code $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }
  }

  Invoke-Step 'Admin frontend build check (vite build)' {
    Push-Location $frontend
    try {
      npm run build
      if ($LASTEXITCODE -ne 0) {
        throw "Frontend build failed with exit code $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }
  }
}

if (-not $SkipFlutter) {
  Invoke-Step 'Flutter regression (flutter test)' {
    Push-Location $flutter
    try {
      flutter test
      if ($LASTEXITCODE -ne 0) {
        throw "Flutter tests failed with exit code $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }
  }
}

Write-Host "`nAll selected quality gates completed." -ForegroundColor Green
