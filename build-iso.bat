@echo off
setlocal

echo JuegaOS ISO: compilacion remota en GitHub Actions
echo La ISO se descargara en la carpeta out, sin instalar Linux en este PC.
echo.
where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo Error: Windows PowerShell no esta disponible.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-iso.ps1"
set "BUILD_EXIT=%ERRORLEVEL%"
if not "%BUILD_EXIT%"=="0" (
    echo.
    echo No se pudo completar o descargar la ISO.
    pause
)

exit /b %BUILD_EXIT%
