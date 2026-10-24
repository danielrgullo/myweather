import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "../code/weather.js" as W

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property var retryDelays: [1, 2, 5, 10]   // minutos
    readonly property int staleMs: 60 * 60 * 1000      // > 1h = desatualizado

    property var weather: null
    property string errorText: ""
    property bool busy: false
    property double now: Date.now()
    property double nextAttemptAt: 0
    property int retryIndex: 0
    property var xhr: null

    readonly property bool stale: !weather || now - weather.updatedAt > staleMs
    readonly property string iconName: weather
        ? W.iconFor(weather.current.code, weather.current.isDay)
        : "weather-none-available"

    property int generation: 0   // descarta respostas de requisições substituídas

    function refresh() {
        const g = ++generation;
        if (xhr) {
            const old = xhr;
            xhr = null;
            old.abort();
        }
        busy = true;
        watchdog.restart();
        xhr = W.fetchOpenMeteo(cfg.latitude, cfg.longitude, function (err, data) {
            if (g !== generation)
                return;
            if (!err)
                return finished(null, data);
            console.warn("myweather: Open-Meteo falhou (" + err + "), tentando MET Norway");
            watchdog.restart();
            xhr = W.fetchMetNo(cfg.latitude, cfg.longitude, function (err2, data2) {
                if (g === generation)
                    finished(err2, data2);
            });
        });
    }

    function finished(err, data) {
        watchdog.stop();
        xhr = null;
        busy = false;
        now = Date.now();
        if (err) {
            errorText = err;
            nextAttemptAt = now + retryDelays[Math.min(retryIndex, retryDelays.length - 1)] * 60000;
            retryIndex++;
        } else {
            weather = data;
            errorText = "";
            retryIndex = 0;
            nextAttemptAt = now + cfg.refreshMinutes * 60000;
        }
    }

    // Um único timer de 1 min: atualiza o "agora", agenda atualizações/retries e,
    // como dispara logo após voltar da suspensão, cobre esse caso também.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (!root.busy && root.now >= root.nextAttemptAt)
                root.refresh();
        }
    }

    // Aborta requisições penduradas; o abort cai no callback de erro (e no fallback).
    Timer {
        id: watchdog
        interval: 20000
        onTriggered: {
            const x = root.xhr;
            if (!x)
                return;
            x.abort();
            if (root.xhr === x)   // abort não disparou o callback
                root.finished("tempo esgotado", null);
        }
    }

    function reloadForNewLocation() {
        weather = null;
        retryIndex = 0;
        refresh();
    }

    Connections {
        target: Plasmoid.configuration
        // latitude e longitude mudam juntas: callLater agrupa numa única atualização
        function onLatitudeChanged() { Qt.callLater(root.reloadForNewLocation); }
        function onLongitudeChanged() { Qt.callLater(root.reloadForNewLocation); }
        function onRefreshMinutesChanged() {
            if (root.weather && root.errorText === "")
                root.nextAttemptAt = root.weather.updatedAt + root.cfg.refreshMinutes * 60000;
        }
    }

    onExpandedChanged: (isExpanded) => {
        now = Date.now();
        if (isExpanded && !busy && (!weather || now - weather.updatedAt > 15 * 60000))
            refresh();
    }

    Component.onCompleted: refresh()

    Plasmoid.icon: iconName
    toolTipMainText: weather
        ? W.fmtTemp(weather.current.temp) + " " + W.describe(weather.current.code)
        : "Previsão do tempo"
    toolTipSubText: {
        let s = cfg.cityName;
        if (weather)
            s += "\nAtualizado às " + Qt.formatTime(new Date(weather.updatedAt), "HH:mm") + " · " + weather.source;
        if (stale)
            s += "\n⚠ Dados desatualizados";
        return s;
    }

    compactRepresentation: CompactView {}
    fullRepresentation: FullView {}
}
