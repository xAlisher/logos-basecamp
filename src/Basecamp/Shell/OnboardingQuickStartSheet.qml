pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "OnboardingDefaults.js" as Defaults

// "See what Quick start sets up": the defaults, read from the same list Quick
// start applies. A dim layer over the welcome page; Esc, Close or
// a click outside dismisses it.
Rectangle {
    id: root

    signal startRequested()
    signal closeRequested()

    color: Theme.palette.scrim
    focus: visible
    Keys.onEscapePressed: root.closeRequested()

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    LogosFrame {
        objectName: "onboardingQuickStartSheet"
        anchors.centerIn: parent
        width: Math.min(root.width - 2 * Theme.spacing.large, 480)
        radius: Theme.spacing.radiusLarge
        backgroundColor: Theme.palette.surfaceRaised
        borderColor: Theme.palette.border

        // Clicks on the sheet stay on the sheet.
        MouseArea { anchors.fill: parent }

        contentItem: ColumnLayout {
            spacing: Theme.spacing.medium

            LogosText {
                text: qsTr("Quick start sets up")
                color: Theme.palette.text
                font.pixelSize: 18
                font.weight: Theme.typography.weightBold
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.spacing.large
                rowSpacing: Theme.spacing.small

                // Label, value, label, value… so the grid pairs them per row.
                Repeater {
                    model: Defaults.summary().reduce((cells, r) => cells.concat([r.label, r.value]), [])
                    delegate: LogosText {
                        id: cell
                        required property string modelData
                        required property int index
                        readonly property bool isValue: cell.index % 2 === 1
                        objectName: isValue ? "onboardingQuickStartValue" : "onboardingQuickStartLabel"
                        Layout.fillWidth: cell.isValue
                        text: cell.modelData
                        color: cell.isValue ? Theme.palette.text : Theme.palette.textSecondary
                        font.pixelSize: Theme.typography.secondaryText
                        wrapMode: cell.isValue ? Text.WordWrap : Text.NoWrap
                    }
                }
            }

            LogosText {
                Layout.fillWidth: true
                text: qsTr("Change any of this later in Settings.")
                color: Theme.palette.textTertiary
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Item { Layout.fillWidth: true }

                LogosButton {
                    objectName: "onboardingQuickStartClose"
                    Layout.preferredHeight: 44
                    text: qsTr("Close")
                    onClicked: root.closeRequested()
                }

                LogosButton {
                    objectName: "onboardingQuickStartStart"
                    Layout.preferredHeight: 44
                    variant: LogosButton.Variant.Primary
                    text: qsTr("Start with these")
                    onClicked: root.startRequested()
                }
            }
        }
    }
}
