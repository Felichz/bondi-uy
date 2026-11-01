@echo off
rem BondiUY: doble clic abre la app en modo simulado.
rem Desde una terminal:  bondi [simulado|real|grabado|test|otp|emulador|deps|parar|ayuda]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bondi.ps1" %*
if "%~1"=="" pause
