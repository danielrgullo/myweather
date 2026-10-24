#!/bin/sh
# Garante que todo ícone usado pelo widget existe no tema Breeze instalado.
set -eu
QML=${QML:-/usr/lib64/qt6/bin/qml}
# no toolbox o tema do host fica em /run/host
for d in /usr/share/icons/breeze /run/host/usr/share/icons/breeze; do
    [ -d "$d" ] && ICONS=$d && break
done
[ -n "${ICONS:-}" ] || { echo "tema Breeze não encontrado"; exit 1; }

missing=0
names=$(QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen "$QML" "$(dirname "$0")/dump-icons.qml" 2>&1 | sed -n 's/.*ICON //p')
[ -n "$names" ] || { echo "nenhum ícone listado (erro no dump-icons.qml?)"; exit 1; }
for n in $names; do
    if [ -z "$(find "$ICONS" -name "$n.svg" -print -quit)" ]; then
        echo "FALTANDO: $n"
        missing=1
    fi
done
[ $missing -eq 0 ] && echo "ok: $(echo "$names" | wc -w) ícones encontrados em $ICONS"
exit $missing
