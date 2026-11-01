import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "../code/weather.js" as W

Item {
    id: full

    readonly property var w: root.weather
    readonly property var today: w ? w.days[0] : null

    function precipText(day) {
        if (!day) return "–";
        let parts = [];
        if (day.precipProb !== null && day.precipProb !== undefined) parts.push(day.precipProb + "%");
        if (day.precipMm > 0) parts.push(day.precipMm.toFixed(1).replace(".", ",") + " mm");
        return parts.length ? parts.join(" · ") : "0 mm";
    }

    // 22 gridUnits: a maior palavra das descrições ("Predominantemente") cabe ao lado
    // do ícone e da grade mesmo com "Chuva hoje" longa ("100% · 17,5 mm").
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: content.implicitHeight + content.anchors.margins * 2

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        // Cabeçalho: cidade, hora da atualização, botão de atualizar
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaExtras.Heading {
                    level: 3
                    text: Plasmoid.configuration.cityName
                    textFormat: Text.PlainText   // vem da API de geocodificação
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: full.w
                        ? "Atualizado às " + Qt.formatTime(new Date(full.w.updatedAt), "HH:mm") + " · " + full.w.source
                        : (root.busy ? "Carregando…" : "Sem dados")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: !root.busy
                onClicked: root.refresh()
                PlasmaComponents.ToolTip { text: "Atualizar agora" }
            }
        }

        // Aviso de dados velhos / erro: nunca mostrar dado antigo como se fosse atual
        PlasmaComponents.Label {
            visible: (root.stale && !root.busy) || root.errorText !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: root.stale ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
            text: (root.stale ? "⚠ Dados desatualizados. " : "")
                + (root.errorText ? "Falha ao atualizar: " + root.errorText + ". Nova tentativa em breve." : "")
        }

        // Agora
        RowLayout {
            visible: !!full.w
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            opacity: root.stale ? 0.5 : 1

            Kirigami.Icon {
                source: root.iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaExtras.Heading {
                    level: 1
                    text: full.w ? W.fmtTemp(full.w.current.temp) : ""
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: full.w ? W.describe(full.w.current.code) : ""
                    wrapMode: Text.Wrap   // só parte a palavra se ela não couber sozinha na linha
                }
            }
            GridLayout {
                columns: 2
                rowSpacing: 0
                columnSpacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label { text: "Sensação"; opacity: 0.7; visible: !!full.w && full.w.current.feels !== null }
                PlasmaComponents.Label { text: full.w ? W.fmtTemp(full.w.current.feels) : ""; visible: !!full.w && full.w.current.feels !== null }
                PlasmaComponents.Label { text: "Mín / Máx"; opacity: 0.7 }
                PlasmaComponents.Label { text: full.today ? W.fmtTemp(full.today.min) + " / " + W.fmtTemp(full.today.max) : "" }
                PlasmaComponents.Label { text: "Umidade"; opacity: 0.7 }
                PlasmaComponents.Label { text: full.w ? Math.round(full.w.current.humidity) + "%" : "" }
                PlasmaComponents.Label { text: "Vento"; opacity: 0.7 }
                PlasmaComponents.Label { text: full.w ? Math.round(full.w.current.wind) + " km/h" : "" }
                PlasmaComponents.Label { text: "Chuva hoje"; opacity: 0.7 }
                PlasmaComponents.Label { text: full.precipText(full.today) }
            }
        }

        Kirigami.Separator {
            visible: !!full.w
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        // Próximos 3 dias
        RowLayout {
            visible: !!full.w
            Layout.fillWidth: true
            opacity: root.stale ? 0.5 : 1

            Repeater {
                model: full.w ? full.w.days.slice(1) : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1   // colunas de mesma largura
                    spacing: 0

                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const s = Qt.locale().dayName(modelData.date.getDay(), Locale.ShortFormat);
                            return s.charAt(0).toUpperCase() + s.slice(1) + " " + modelData.date.getDate();
                        }
                        font.bold: true
                    }
                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                        source: W.iconFor(modelData.code, true)
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: W.fmtTemp(modelData.max) + " / " + W.fmtTemp(modelData.min)
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: W.describe(modelData.code)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "☂ " + full.precipText(modelData)
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }
}
