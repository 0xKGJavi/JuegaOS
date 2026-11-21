#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SOURCE="$ROOT_DIR/profile"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/out}"

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

[[ "$(uname -s)" == Linux ]] || fail "La ISO debe compilarse en Linux."
[[ "$(uname -m)" == x86_64 ]] || fail "El perfil solo admite x86_64."
[[ "$EUID" -ne 0 ]] || fail "Ejecuta este script como usuario normal, no como root."

for command in git makepkg mkarchiso repo-add sudo; do
    command -v "$command" >/dev/null 2>&1 || fail "Falta '$command'. Instala archiso, base-devel, git y pacman-contrib."
done

RELENG_DIR="/usr/share/archiso/configs/releng"
[[ -d "$RELENG_DIR" ]] || fail "No se encontró el perfil Archiso releng en $RELENG_DIR."
sudo -v

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/juegaos-build.XXXXXXXX")"
PROFILE_DIR="$WORK_DIR/profile"
LOCAL_REPO="$WORK_DIR/localrepo"
CALAMARES_DIR="$WORK_DIR/calamares"

cleanup() {
    sudo rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$LOCAL_REPO" "$OUTPUT_DIR" "$WORK_DIR/out"
cp -a "$RELENG_DIR/." "$PROFILE_DIR"
cp "$PROFILE_SOURCE/profiledef.sh" "$PROFILE_DIR/profiledef.sh"
cp "$PROFILE_SOURCE/packages.x86_64" "$PROFILE_DIR/packages.x86_64"
cp -a "$PROFILE_SOURCE/airootfs/." "$PROFILE_DIR/airootfs/"

if ! grep -q '^\[multilib\]$' "$PROFILE_DIR/pacman.conf"; then
    sed -i '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/s/^#//' \
        "$PROFILE_DIR/pacman.conf"
fi
grep -q '^\[multilib\]$' "$PROFILE_DIR/pacman.conf" \
    || fail "No se pudo habilitar multilib en el perfil Archiso."

# The live and installed systems must never inherit the temporary local repo.
install -D -m 0644 "$PROFILE_DIR/pacman.conf" "$PROFILE_DIR/airootfs/etc/pacman.conf"
mkdir -p "$PROFILE_DIR/airootfs/etc/systemd/system/graphical.target.wants"
ln -sfn /etc/systemd/system/juegaos-live-user.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/graphical.target.wants/juegaos-live-user.service"
ln -sfn /usr/lib/systemd/system/sddm.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/graphical.target.wants/sddm.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/graphical.target.wants/NetworkManager.service"
ln -sfn /usr/lib/systemd/system/bluetooth.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/graphical.target.wants/bluetooth.service"
ln -sfn /usr/lib/systemd/system/vboxservice.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/graphical.target.wants/vboxservice.service"
rm -f "$PROFILE_DIR/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf"

git clone --depth 1 https://aur.archlinux.org/calamares.git "$CALAMARES_DIR"
printf 'Revisa el PKGBUILD de AUR antes de compilarlo: %s/PKGBUILD\n' "$CALAMARES_DIR"
if [[ "${JUEGAOS_AUR_APPROVED:-0}" == 1 ]]; then
    printf 'AUR PKGBUILD approval provided by the caller.\n'
else
    read -r -p "¿Confirmas que quieres compilar este PKGBUILD? [y/N] " aur_approval
    [[ "$aur_approval" == y || "$aur_approval" == Y ]] || fail "Compilación de AUR cancelada."
fi
(
    cd "$CALAMARES_DIR"
    makepkg --syncdeps --cleanbuild --clean --noconfirm
)

shopt -s nullglob
CALAMARES_PACKAGES=("$CALAMARES_DIR"/*.pkg.tar.zst)
shopt -u nullglob
[[ "${#CALAMARES_PACKAGES[@]}" -eq 1 ]] || fail "Se esperaba exactamente un paquete compilado de Calamares."
repo-add "$LOCAL_REPO/juegaos-local.db.tar.gz" "${CALAMARES_PACKAGES[0]}"

cat >> "$PROFILE_DIR/pacman.conf" <<EOF

[juegaos-local]
SigLevel = Optional TrustAll
Server = file://$LOCAL_REPO
EOF

sudo mkarchiso -v -w "$WORK_DIR/work" -o "$WORK_DIR/out" "$PROFILE_DIR"

shopt -s nullglob
ISO_FILES=("$WORK_DIR/out"/*.iso)
shopt -u nullglob
[[ "${#ISO_FILES[@]}" -gt 0 ]] || fail "mkarchiso no produjo una imagen ISO."

shopt -s nullglob
ARTIFACTS=("$WORK_DIR/out"/*)
shopt -u nullglob

for artifact in "${ARTIFACTS[@]}"; do
    [[ -f "$artifact" ]] || continue
    sudo chmod 0644 "$artifact"
    install -D -m 0644 "$artifact" "$OUTPUT_DIR/$(basename "$artifact")"
done

printf 'ISO creada en: %s\n' "$OUTPUT_DIR"
