# BondiUY: un solo comando para todo.
#
#   bondi                 abre la app en modo simulado (prende OTP y emulador si hace falta)
#   bondi demo            abre la demo (viajes grabados, sin servidores) en el emulador
#   bondi web             compila la demo web en build\web (para bondiuy.medanolabs.com o el portfolio)
#   bondi apk             compila el APK de la demo en dist\BondiUY-demo.apk
#   bondi real            usa GPS y buses reales (necesita config/dev.json para buses en vivo)
#   bondi grabado         sin OTP: viaje grabado Saldanha da Gama -> Plaza Independencia
#   bondi test            corre todas las pruebas (capturas en build/capturas)
#   bondi otp             solo prende el servidor OTP
#   bondi emulador        solo prende el emulador
#   bondi deps            actualiza dependencias (tras cambiar pubspec.yaml)
#   bondi parar           apaga el servidor OTP
#
# (Sin tildes a proposito: PowerShell 5.1 lee mal los .ps1 UTF-8 sin BOM.)

param(
  [ValidateSet('simulado', 'real', 'grabado', 'demo', 'web', 'apk', 'test', 'otp', 'emulador', 'deps', 'parar', 'ayuda')]
  [string]$Comando = 'simulado',
  # Solo para `web`: ruta donde se va a servir (el portfolio usa /apps/bondiuy/).
  [string]$Base = '/'
)

$ErrorActionPreference = 'Stop'
$Raiz = Split-Path -Parent $PSScriptRoot
$Flutter = Join-Path $Raiz '..\bondi-uy-flutter\flutter\bin\flutter.bat'
$Sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$Adb = Join-Path $Sdk 'platform-tools\adb.exe'
$EmuExe = Join-Path $Sdk 'emulator\emulator.exe'
$Avd = 'bondi_api35'
$OtpDir = Join-Path $env:USERPROFILE 'otp'
$OtpJar = Join-Path $OtpDir 'otp-shaded-2.7.0.jar'
$OtpUrl = 'http://localhost:8080/otp/'

function Paso($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }
function Ok($texto) { Write-Host "    $texto" -ForegroundColor Green }
function Falla($texto) { Write-Host "    $texto" -ForegroundColor Red; exit 1 }

function OtpVivo {
  try { Invoke-WebRequest -Uri $OtpUrl -UseBasicParsing -TimeoutSec 3 | Out-Null; return $true }
  catch { return $false }
}

function Prender-Otp {
  Paso 'Servidor OTP'
  if (OtpVivo) { Ok 'ya estaba corriendo en localhost:8080'; return }
  if (-not (Test-Path $OtpJar)) { Falla "no encuentro $OtpJar" }
  if (-not (Test-Path (Join-Path $OtpDir 'graph.obj'))) {
    Ok 'construyendo el grafo (una sola vez, ~3 min)...'
    Push-Location $OtpDir
    & java -Xmx6G -jar $OtpJar --build --save . | Out-Null
    Pop-Location
  }
  Ok 'prendiendo (queda en una ventana aparte, minimizada)...'
  Start-Process java -ArgumentList '-Xmx3G', '-jar', $OtpJar, '--load', '--serve', '.' `
    -WorkingDirectory $OtpDir -WindowStyle Minimized | Out-Null
  for ($i = 0; $i -lt 90; $i++) {
    if (OtpVivo) { Ok 'listo en localhost:8080'; return }
    Start-Sleep -Seconds 2
  }
  Falla 'OTP no respondio a tiempo (revisa la ventana de java)'
}

function Emulador-Listo {
  $d = & $Adb devices 2>$null | Select-String 'emulator-\d+\s+device'
  if (-not $d) { return $false }
  $b = (& $Adb -s emulator-5554 shell getprop sys.boot_completed 2>$null)
  return ($b -and $b.Trim() -eq '1')
}

function Prender-Emulador {
  Paso 'Emulador Android'
  if (Emulador-Listo) { Ok 'ya estaba prendido'; return }
  $d = & $Adb devices 2>$null | Select-String 'emulator-\d+'
  if (-not $d) {
    Ok "prendiendo $Avd..."
    Start-Process $EmuExe -ArgumentList '-avd', $Avd, '-no-snapshot-save', '-no-boot-anim', '-gpu', 'swiftshader_indirect' `
      -WindowStyle Normal | Out-Null
  }
  for ($i = 0; $i -lt 90; $i++) {
    if (Emulador-Listo) { Ok 'listo'; return }
    Start-Sleep -Seconds 3
  }
  Falla 'el emulador no termino de arrancar'
}

function Dependencias {
  Paso 'Dependencias'
  # Flutter en Windows pide "Modo desarrollador" para los plugins de
  # escritorio; se ocultan esas carpetas un momento para no necesitarlo.
  $escritorio = @('windows', 'linux', 'macos') | Where-Object { Test-Path (Join-Path $Raiz $_) }
  try {
    foreach ($d in $escritorio) { Rename-Item (Join-Path $Raiz $d) "_${d}_tmp" }
    Push-Location $Raiz
    & $Flutter pub get
  } finally {
    Pop-Location
    foreach ($d in $escritorio) { Rename-Item (Join-Path $Raiz "_${d}_tmp") $d }
  }
  Ok 'listas'
}

function Abrir-App($modo) {
  Paso "Abriendo BondiUY (modo $modo)"
  $argumentos = @('run', '-d', 'emulator-5554', '--no-pub', "--dart-define=BONDI_MODO=$modo")
  $config = Join-Path $Raiz 'config\dev.json'
  if (Test-Path $config) {
    $argumentos += "--dart-define-from-file=$config"
    Ok 'usando credenciales de config\dev.json'
  } elseif ($modo -eq 'real') {
    Ok 'sin config\dev.json: no habra buses en vivo (ver config\dev.example.json)'
  }
  Ok 'la primera vez tarda un par de minutos en compilar'
  Ok 'en esta ventana: r = recargar cambios, R = reiniciar, q = salir'
  Push-Location $Raiz
  try { & $Flutter @argumentos } finally { Pop-Location }
}

# Enlaces de la presentación web (se ven en pantallas anchas; un enlace vacío oculta su botón). El APK lo
# sirve la misma demo: Compilar-Web copia dist/BondiUY-demo.apk al build.
$UrlCodigo = 'https://github.com/Felichz/bondi-uy'
$UrlApk = 'https://bondiuy.medanolabs.com/BondiUY-demo.apk'

function Compilar-Web {
  Paso "Compilando la demo web (base $Base)"
  Push-Location $Raiz
  try {
    & $Flutter build web --release --no-pub --pwa-strategy=none --base-href $Base `
      --dart-define=BONDI_MODO=demo "--dart-define=SOURCE_URL=$UrlCodigo" "--dart-define=APK_URL=$UrlApk"
  } finally { Pop-Location }
  $apk = Join-Path $Raiz 'dist\BondiUY-demo.apk'
  if (-not (Test-Path $apk)) { Falla 'falta dist\BondiUY-demo.apk: compilalo antes con .\scripts\bondi.ps1 apk' }
  Copy-Item $apk (Join-Path $Raiz 'build\web\BondiUY-demo.apk') -Force
  Ok "listo en $(Join-Path $Raiz 'build\web'), con el APK"
  Ok 'publicar: npm run deploy (o npm run deploy:staging)'
}

function Compilar-Apk {
  Paso 'Compilando el APK de la demo'
  Push-Location $Raiz
  try {
    & $Flutter build apk --release --no-pub --dart-define=BONDI_MODO=demo
    New-Item -ItemType Directory -Force (Join-Path $Raiz 'dist') | Out-Null
    Copy-Item (Join-Path $Raiz 'build\app\outputs\flutter-apk\app-release.apk') (Join-Path $Raiz 'dist\BondiUY-demo.apk') -Force
  } finally { Pop-Location }
  Ok "listo: $(Join-Path $Raiz 'dist\BondiUY-demo.apk')"
}

if (-not (Test-Path $Flutter)) { Falla "no encuentro Flutter en $Flutter" }

switch ($Comando) {
  'simulado' { Prender-Otp; Prender-Emulador; Abrir-App 'simulado' }
  'real' { Prender-Otp; Prender-Emulador; Abrir-App 'real' }
  'grabado' { Prender-Emulador; Abrir-App 'grabado' }
  'demo' { Prender-Emulador; Abrir-App 'demo' }
  'web' { Compilar-Web }
  'apk' { Compilar-Apk }
  'test' {
    Paso 'Pruebas'
    Push-Location $Raiz
    try { & $Flutter test --no-pub } finally { Pop-Location }
    Ok "capturas en $(Join-Path $Raiz 'build\capturas')"
  }
  'otp' { Prender-Otp }
  'emulador' { Prender-Emulador }
  'deps' { Dependencias }
  'parar' {
    Paso 'Apagando OTP'
    Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" |
      Where-Object { $_.CommandLine -like '*otp-shaded*' } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Ok "apagado (pid $($_.ProcessId))" }
  }
  'ayuda' { Get-Content $PSCommandPath -TotalCount 15 | Select-Object -Skip 1 }
}
