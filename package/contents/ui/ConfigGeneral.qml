import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../code/weather.js" as W

KCM.SimpleKCM {
    id: page

    property string cfg_cityName
    property real cfg_latitude
    property real cfg_longitude
    property int cfg_refreshMinutes
    property string cfg_cityNameDefault
    property real cfg_latitudeDefault
    property real cfg_longitudeDefault
    property int cfg_refreshMinutesDefault

    property var results: []
    property string status: ""
    property int searchSeq: 0   // ignora respostas de buscas anteriores

    function search() {
        if (query.text.trim() === "")
            return;
        const seq = ++searchSeq;
        status = "Buscando…";
        W.searchCity(query.text.trim(), function (err, list) {
            if (seq !== searchSeq)
                return;
            results = list;
            status = err ? "Erro na busca: " + err : (list.length ? "" : "Nenhuma cidade encontrada");
        });
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.label: "Cidade atual:"
            textFormat: Text.PlainText
            text: page.cfg_cityName + "  (" + page.cfg_latitude.toFixed(3) + ", " + page.cfg_longitude.toFixed(3) + ")"
        }

        RowLayout {
            Kirigami.FormData.label: "Buscar cidade:"
            QQC2.TextField {
                id: query
                placeholderText: "ex.: Curitiba"
                onAccepted: page.search()
            }
            QQC2.Button {
                text: "Buscar"
                icon.name: "search"
                onClicked: page.search()
            }
        }

        QQC2.Label {
            visible: page.status !== ""
            textFormat: Text.PlainText
            text: page.status
        }

        Repeater {
            model: page.results
            delegate: QQC2.RadioButton {
                required property var modelData
                text: modelData.label
                checked: page.cfg_cityName === modelData.label
                onClicked: {
                    page.cfg_cityName = modelData.label;
                    page.cfg_latitude = modelData.latitude;
                    page.cfg_longitude = modelData.longitude;
                }
            }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            Kirigami.FormData.label: "Atualizar a cada (min):"
            from: 10
            to: 180
            stepSize: 5
            value: page.cfg_refreshMinutes
            onValueModified: page.cfg_refreshMinutes = value
        }
    }
}
