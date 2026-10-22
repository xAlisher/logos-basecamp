import QtQuick
import QtQuick.Controls

import Logos.Controls
import Logos.Icons
import Logos.Theme

// A checkable LogosMenuItem that draws its check (LogosMenuItem shows none):
// the filter menu's "Show unavailable", the compact ⋯ menu and the compact
// category picker. Rows keep the menu's height unless `touch` (44 px).
LogosMenuItem {
    id: root

    property bool touch: false
    readonly property int indicatorSize: 14

    checkable: true
    implicitHeight: touch ? Theme.minTouchTarget : Theme.components.menuItem.height

    indicator: LogosIcon {
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.spacing.medium
        width: root.indicatorSize
        height: root.indicatorSize
        visible: root.checked
        source: LogosIcons.check
        color: Theme.palette.text
    }

    contentItem: LogosText {
        leftPadding: Theme.spacing.medium + root.indicatorSize + Theme.spacing.small
        rightPadding: Theme.spacing.medium
        verticalAlignment: Text.AlignVCenter
        text: root.text
        color: root.enabled ? Theme.palette.text : Theme.palette.textMuted
    }
}
