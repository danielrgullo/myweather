import QtQuick
import "../package/contents/code/weather.js" as W

// Imprime (stdout via console.warn) todos os ícones que o widget pode pedir; usado por check-icons.sh.
QtObject {
    Component.onCompleted: {
        const names = new Set(["weather-none-available"]);
        for (const c of W.ALL_CODES) {
            names.add(W.iconFor(c, true));
            names.add(W.iconFor(c, false));
        }
        for (const n of names)
            console.warn("ICON " + n);
        Qt.exit(0);
    }
}
