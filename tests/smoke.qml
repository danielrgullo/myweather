import QtQuick
import "../package/contents/code/weather.js" as W

// Teste com rede: confere que as APIs reais ainda respondem no formato esperado.
// Sai com código 1 se alguma falhar. Rodar com `make smoke`.
QtObject {
    property int pending: 3
    property bool failed: false

    function check(name, err, ok) {
        if (err || !ok) {
            console.warn("FALHOU", name, err || "resultado inesperado");
            failed = true;
        } else {
            console.warn("ok", name);
        }
        if (--pending === 0)
            Qt.exit(failed ? 1 : 0);
    }

    Component.onCompleted: {
        W.fetchOpenMeteo(-23.5475, -46.6361, (err, d) => check("Open-Meteo", err, d && d.days.length === 4));
        W.fetchMetNo(-23.5475, -46.6361, (err, d) => check("MET Norway", err, d && d.days.length === 4));
        W.searchCity("São Paulo", (err, r) => check("Geocodificação", err, r.length > 0));
    }
}
