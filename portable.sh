#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
PORTABLE_DIR="$PROJECT_DIR/StellarTexto-portable"
QT_PREFIX="/opt/qt/6.11.2/gcc_64"

echo "==> Compilando..."
mkdir -p "$BUILD_DIR"
export LD_LIBRARY_PATH="$QT_PREFIX/lib:$LD_LIBRARY_PATH"
cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" -DCMAKE_PREFIX_PATH="$QT_PREFIX"
cmake --build "$BUILD_DIR"

echo "==> Creando portable en $PORTABLE_DIR"
rm -rf "$PORTABLE_DIR"
mkdir -p "$PORTABLE_DIR/lib"
mkdir -p "$PORTABLE_DIR/plugins/platforms"
mkdir -p "$PORTABLE_DIR/plugins/imageformats"
mkdir -p "$PORTABLE_DIR/plugins/iconengines"
mkdir -p "$PORTABLE_DIR/plugins/printsupport"
mkdir -p "$PORTABLE_DIR/plugins/styles"

BINARY="$BUILD_DIR/StellarTexto"

echo "==> Copiando binario..."
cp "$BINARY" "$PORTABLE_DIR/"

echo "==> Copiando librerías Qt y dependencias..."
# Recursive function to copy a library and its dependencies
copy_libs() {
    local lib="$1"
    # Resolve real path
    if [ -L "$lib" ]; then
        lib="$(readlink -f "$lib")"
    fi
    local name="$(basename "$lib")"
    local target="$PORTABLE_DIR/lib/$name"
    if [ -f "$target" ]; then
        return
    fi
    if [ -f "$lib" ]; then
        cp -L "$lib" "$target" 2>/dev/null || true
        chmod 644 "$target" 2>/dev/null || true
        # Create SONAME symlink so the loader finds it (e.g. libQt6Core.so.6 -> libQt6Core.so.6.11.2)
        local soname
        soname=$(objdump -p "$lib" 2>/dev/null | awk '/SONAME/ {print $2; exit}')
        if [ -n "$soname" ] && [ "$soname" != "$name" ]; then
            ln -sf "$name" "$PORTABLE_DIR/lib/$soname"
        fi
        # Get dependencies of this lib
        local deps
        deps=$(ldd "$lib" 2>/dev/null | grep "=> /" | awk '{print $3}' | sort -u || true)
        for dep in $deps; do
            copy_libs "$dep"
        done
    fi
}

# Copiar todas las .so del binario
qt_libs=$(ldd "$BINARY" | grep "=> /" | awk '{print $3}' | sort -u)
for lib in $qt_libs; do
    copy_libs "$lib"
done

echo "==> Copiando plugins de Qt..."
# Platform plugin (QPA) - libqxcb is the XCB platform plugin
cp -L "$QT_PREFIX/plugins/platforms/libqxcb.so" "$PORTABLE_DIR/plugins/platforms/"

# Image format plugins
shopt -s nullglob
for plugin in "$QT_PREFIX/plugins/imageformats/"*.so; do
    cp -L "$plugin" "$PORTABLE_DIR/plugins/imageformats/"
done

# Icon engine plugins
for plugin in "$QT_PREFIX/plugins/iconengines/"*.so; do
    cp -L "$plugin" "$PORTABLE_DIR/plugins/iconengines/"
done

# Print support plugins
for plugin in "$QT_PREFIX/plugins/printsupport/"*.so; do
    cp -L "$plugin" "$PORTABLE_DIR/plugins/printsupport/"
done

# Style plugins (may be empty)
for plugin in "$QT_PREFIX/plugins/styles/"*.so; do
    cp -L "$plugin" "$PORTABLE_DIR/plugins/styles/"
done
shopt -u nullglob

# Also copy any transitive dependencies of plugins
echo "==> Copiando dependencias de plugins..."
for so in $(find "$PORTABLE_DIR/plugins" -name "*.so"); do
    plugin_deps=$(ldd "$so" 2>/dev/null | grep "=> /" | awk '{print $3}' | sort -u || true)
    for dep in $plugin_deps; do
        copy_libs "$dep"
    done
done

echo "==> Fijando RPATH con \$ORIGIN (todo autorreferencial)..."
# RPATH forzado: tiene prioridad sobre LD_LIBRARY_PATH del sistema,
# así el portable NUNCA depende de librerías del sistema.
patchelf --force-rpath --set-rpath '$ORIGIN/lib' "$PORTABLE_DIR/StellarTexto"
for lib in "$PORTABLE_DIR/lib/"*.so*; do
    [ -L "$lib" ] && continue
    patchelf --force-rpath --set-rpath '$ORIGIN' "$lib" 2>/dev/null || true
done
for plugin in "$PORTABLE_DIR/plugins/"*/*.so; do
    patchelf --force-rpath --set-rpath '$ORIGIN/../../lib' "$plugin" 2>/dev/null || true
done

echo "==> Creando lanzador..."
cat > "$PORTABLE_DIR/AppRun" << 'LAUNCHER'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"
export QT_PLUGIN_PATH="$DIR/plugins"
exec "$DIR/StellarTexto" "$@"
LAUNCHER
chmod +x "$PORTABLE_DIR/AppRun"

echo "==> Copiando .desktop e icono..."
cp "$PROJECT_DIR/icons/stellartexto.png" "$PORTABLE_DIR/"
sed "s|@BINDIR@|$PORTABLE_DIR|g" "$PROJECT_DIR/StellarTexto.desktop" > "$PORTABLE_DIR/StellarTexto.desktop"

echo ""
echo "Portable creado en: $PORTABLE_DIR"
echo "Usar: $PORTABLE_DIR/AppRun"
echo "Tamaño: $(du -sh "$PORTABLE_DIR" | cut -f1)"
