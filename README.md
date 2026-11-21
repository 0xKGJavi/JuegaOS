# JuegaOS

JuegaOS es un perfil de Arch Linux para crear una ISO x86_64 con escritorio KDE,
instalador gráfico Calamares y una experiencia de consola basada en Steam Big
Picture.

## Incluye

- KDE Plasma, SDDM y NetworkManager.
- Steam, Lutris, Flatpak, Firefox y compatibilidad gráfica Vulkan de Intel/AMD.
- 0 A.D. y SuperTuxKart, juegos libres que se pueden distribuir legalmente.
- Calamares para instalar el sistema en disco.
- En el primer inicio de sesión instalado, un asistente descarga Heroic Games
  Launcher desde Flathub para acceder a las cuentas de Epic y GOG.
- Invitado de VirtualBox (`vboxservice`) y controladores Mesa para la VM.

Los juegos comerciales no se incluyen ni se desbloquean. El usuario inicia
sesión en sus propias cuentas y descarga los juegos que haya adquirido. Heroic
es un cliente de terceros, no el cliente oficial de Epic o GOG; la compatibilidad
de cada juego depende de Proton/Wine, sus medidas antitrampas y sus licencias.

## Estado y limitaciones

Este repositorio contiene el perfil y el constructor, no una ISO ya compilada.
La ISO debe construirse en Arch Linux x86_64 y probarse en VirtualBox antes de
considerarla lista para instalar. No tienes que instalar JuegaOS en tu PC:
puedes descargar la ISO y usarla en VirtualBox. La compilación remota descrita
abajo evita instalar Linux o herramientas de compilación en tu equipo.

VirtualBox sirve para probar el arranque, el instalador y juegos ligeros. Su
aceleración 3D no equivale a una GPU física y no es una plataforma adecuada para
medir el rendimiento de juegos modernos.

## Compilar en Arch Linux

Instala las herramientas base:

```sh
sudo pacman -S --needed archiso base-devel git pacman-contrib
```

El constructor parte del perfil oficial `releng`, habilita `multilib` solo para
la compilación y deja la configuración temporal fuera del sistema instalado.
Ejecuta el constructor como usuario normal:

```sh
sudo pacman -Syu
bash build-iso.sh
```

### Obtener la ISO sin instalar herramientas en tu PC

1. Publica este proyecto en un repositorio público independiente llamado
   `0xKGJavi/JuegaOS`.
2. Ejecuta `build-iso.bat`; abrirá directamente las Actions del repositorio.
3. Abre **Build JuegaOS ISO → Run workflow**. Cuando termine, descarga `juegaos-iso` de esa
   ejecución; incluye la ISO y `SHA256SUMS`, y se conserva durante siete días.
4. En VirtualBox, monta la ISO en una máquina virtual. No la instales en el
   disco físico de tu PC.

GitHub Actions compila el paquete Calamares disponible en AUR en ese momento.
Usa un runner temporal y no instala nada en tu PC. La disponibilidad depende
de los límites de Actions y del espacio de almacenamiento de artefactos de tu
cuenta. La ISO todavía debe probarse en VirtualBox.

### Compilación local opcional

En Windows, compilar localmente todavía requiere un Arch Linux bajo WSL. Para
la descarga remota no hace falta instalar WSL.

1. Si WSL aún no está instalado, abre PowerShell como administrador, ejecuta
   `wsl --install` y reinicia cuando Windows lo solicite.
2. Instala ArchWSL desde sus [releases oficiales del proyecto](https://github.com/yuk7/ArchWSL/releases/latest).
   Extrae el ZIP en una carpeta tuya y ejecuta `Arch.exe` una vez para registrar
   e inicializar la distribución.
3. En Arch, instala las herramientas indicadas arriba, desde la sección
   «Compilar en Arch Linux».
4. En Arch, abre la carpeta del proyecto y ejecuta `bash build-iso.sh`. La ISO
   queda en `out/` junto al proyecto.

El constructor obtiene el paquete de Calamares desde AUR, crea un repositorio
local temporal y construye la ISO a partir del perfil `releng` de Archiso. Lee
y construye el PKGBUILD de AUR; revisa ese archivo antes de ejecutarlo. No
ejecutes `makepkg` como root. El resultado se deja en `out/`.

## Probar en VirtualBox

1. Crea una VM Linux de 64 bits con al menos 4 GB de RAM y 40 GB de disco.
2. Activa EFI para probar el arranque UEFI; la ISO también incluye arranque
   BIOS heredado.
3. Monta la ISO, arranca en modo live y comprueba KDE, red y Calamares.
4. Instala en el disco virtual, reinicia y verifica el inicio de sesión,
   audio, Steam Big Picture y la descarga de Heroic.
5. Prueba SuperTuxKart y 0 A.D. con la aceleración 3D de VirtualBox activada.

La creación de esta ISO no sustituye las pruebas en hardware real; los
controladores NVIDIA y las funciones de mandos Bluetooth deben validarse en el
equipo de destino.
