import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../code/weather.js" as W

MouseArea {
    id: compact

    // Na bandeja do sistema o espaço é quadrado: temperatura vira um selo sobre o ícone.
    readonly property bool inTray: !!(Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentForcesSquarePlasmoids)
    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property string tempText: root.weather ? W.fmtTemp(root.weather.current.temp) : "–"

    Layout.minimumWidth: (!inTray && horizontal) ? row.implicitWidth : -1

    hoverEnabled: true
    onClicked: root.expanded = !root.expanded

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.fillHeight: true
            Layout.fillWidth: compact.inTray || !compact.horizontal
            Layout.preferredWidth: height
            source: root.iconName
            active: compact.containsMouse
            opacity: root.stale ? 0.4 : 1

            PlasmaComponents.Label {
                visible: compact.inTray || !compact.horizontal
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: compact.tempText
                font.pixelSize: Math.max(parent.height * 0.4, Kirigami.Theme.smallFont.pixelSize)
                font.bold: true
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }

        PlasmaComponents.Label {
            visible: !compact.inTray && compact.horizontal
            text: compact.tempText
            opacity: root.stale ? 0.6 : 1
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
        }
    }
}
