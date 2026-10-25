import QtQuick

import Logos.Theme
import Logos.Controls

// The desktop layout's Basecamp overlay (basecamp-experiments#43): a dimmed
// desktop with a rounded panel in the middle. The home app's own view sits
// inside the panel as a separate widget the C++ side places over it
// (HomeOverlayGeometry.h); this page only draws what is around it. The panel
// is the home page's background colour, so its corners read as the page's.
// A click outside the panel asks to close; Esc and Ctrl+K are the shell's.
Item {
    id: root

    property int panelX: 0
    property int panelY: 0
    property int panelWidth: 0
    property int panelHeight: 0
    // Nothing can fill `home`: the panel says so itself.
    property bool noHome: false

    signal dismissRequested()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    MouseArea {
        objectName: "homeOverlay.scrim"
        anchors.fill: parent
        onClicked: root.dismissRequested()
    }

    Rectangle {
        objectName: "homeOverlay.panel"
        x: root.panelX
        y: root.panelY
        width: root.panelWidth
        height: root.panelHeight
        radius: Theme.spacing.radiusXlarge
        color: Theme.palette.background
        border.color: Theme.palette.border
        border.width: 1

        // Clicks on the panel stay on the panel.
        MouseArea { anchors.fill: parent }

        Column {
            visible: root.noHome
            anchors.centerIn: parent
            width: Math.min(420, parent.width - 48)
            spacing: Theme.spacing.small

            LogosText {
                objectName: "homeOverlay.noHome"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("No home page")
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: Theme.palette.text
            }
            LogosText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Basecamp's Home app isn't installed, and no other installed app is set as Home. Choose one in Settings, Default apps, or reinstall Basecamp. Your open apps are in the dock.")
                font.pixelSize: 14
                color: Theme.palette.textSecondary
            }
        }
    }
}
