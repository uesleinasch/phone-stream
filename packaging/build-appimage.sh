#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
BUILD="$ROOT/build/appimage"
APPDIR="$BUILD/AppDir"
DIST="$ROOT/dist"
TOOL="$BUILD/appimagetool-x86_64.AppImage"
TOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
FLUTTER="${FLUTTER:-$(command -v flutter || echo "$HOME/.local/share/flutter/bin/flutter")}"

info() { printf '\e[36m→ %s\e[0m\n' "$*" >&2; }

[[ -x $FLUTTER ]] || { echo "Flutter não encontrado (defina FLUTTER=/caminho/para/flutter)" >&2; exit 1; }

info "Compilando a interface Flutter..."
(cd "$ROOT/gui" && "$FLUTTER" build linux --release)

info "Baixando o scrcpy para embutir..."
rm -rf "$BUILD/home"
HOME="$BUILD/home" XDG_DATA_HOME="" PHONE_STREAM_SCRCPY_DIR="" "$ROOT/phone-stream" --install

info "Montando o AppDir..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib"
cp -r "$ROOT/gui/build/linux/x64/release/bundle" "$APPDIR/usr/lib/phone-stream-gui"
cp -r "$BUILD/home/.local/share/phone-stream/scrcpy" "$APPDIR/usr/lib/scrcpy"
install -m 755 "$ROOT/phone-stream" "$APPDIR/usr/bin/phone-stream"
install -m 755 "$ROOT/packaging/AppRun" "$APPDIR/AppRun"
cp "$ROOT/packaging/phone-stream.desktop" "$ROOT/packaging/phone-stream.svg" "$APPDIR/"
ln -s phone-stream.svg "$APPDIR/.DirIcon"

if [[ ! -x $TOOL ]]; then
  info "Baixando o appimagetool..."
  curl -fL --progress-bar -o "$TOOL" "$TOOL_URL"
  chmod +x "$TOOL"
fi

mkdir -p "$DIST"
info "Gerando o AppImage..."
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$APPDIR" "$DIST/phone-stream-x86_64.AppImage"
info "Pronto: $DIST/phone-stream-x86_64.AppImage"
