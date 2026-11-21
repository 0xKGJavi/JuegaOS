@echo off
setlocal

echo JuegaOS ISO
echo.
echo Abriendo las Actions del repositorio publico JuegaOS.
echo.
echo Pulsa "Build JuegaOS ISO" y luego "Run workflow".
echo Cuando termine, descarga el artefacto "juegaos-iso".
echo.
echo No se instalara Linux ni JuegaOS en este PC.
echo.
start "" "https://github.com/0xKGJavi/JuegaOS/actions/workflows/build-juegaos-iso.yml"
if errorlevel 1 (
    echo No se pudo abrir el navegador. Visita:
    echo https://github.com/0xKGJavi/JuegaOS/actions/workflows/build-juegaos-iso.yml
)
pause
exit /b 0
