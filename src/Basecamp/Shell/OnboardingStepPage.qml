pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

// One setup step: the title, the step rail and the footer around its content.
// `objectPrefix` names the controls, unique per step since every step has its
// own.
Item {
    id: root

    property string objectPrefix: "onboarding"
    property var stepNames: []
    property int stepIndex: 0
    property bool canGoBack: false
    property bool canAdvance: true
    property string advanceText: ""
    property string advanceHint: ""
    // A second way forward beside the advance button, e.g. Retry. Hidden when empty.
    property string secondaryText: ""
    property string subtitle: qsTr("Custom setup: choose what Basecamp installs, runs and looks like.")

    // The step itself, filling the space between the rail and the footer.
    default property alias content: contentArea.data

    signal backRequested()
    signal advanceRequested()
    signal secondaryRequested()

    // Phone widths: smaller margins, and the footer stacks (see below).
    readonly property bool narrow: width < 600

    ColumnLayout {
        anchors.fill: parent
        // The page is the whole window, not a view inside Basecamp's chrome.
        anchors.margins: root.narrow ? Theme.spacing.large : Theme.spacing.xxlarge
        spacing: Theme.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            LogosText {
                text: qsTr("Set up Basecamp")
                color: Theme.palette.text
                font.pixelSize: Theme.typography.titleText
                font.weight: Theme.typography.weightBold
            }

            LogosText {
                text: root.subtitle
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                font.pixelSize: Theme.typography.secondaryText
            }
        }

        RowLayout {
            objectName: root.objectPrefix + "StepRail"
            visible: root.stepNames.length > 1
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            Repeater {
                model: root.stepNames

                delegate: ColumnLayout {
                    id: railStep
                    required property int index
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: railStep.index <= root.stepIndex ? Theme.palette.primary
                                                                : Theme.palette.border
                    }

                    LogosText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: (railStep.index + 1) + ". " + railStep.modelData
                        color: railStep.index === root.stepIndex ? Theme.palette.text
                                                                 : Theme.palette.textTertiary
                        font.pixelSize: 11
                        font.weight: railStep.index === root.stepIndex
                            ? Theme.typography.weightBold
                            : Theme.typography.weightRegular
                    }
                }
            }
        }

        LogosScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            // The content Item sets only `height`; without this the view
            // reads its implicit height (0) and a long step can't scroll.
            contentHeight: contentArea.height

            Item {
                id: contentArea
                width: scroll.availableWidth
                height: Math.max(scroll.availableHeight,
                                 children.length > 0 ? children[0].implicitHeight : 0)
            }
        }

        // Wide: Back on the left, the way forward on the right.
        RowLayout {
            visible: !root.narrow
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            LogosButton {
                objectName: root.objectPrefix + "BackButton"
                visible: root.canGoBack
                text: qsTr("Back")
                onClicked: root.backRequested()
            }

            Item { Layout.fillWidth: true }

            LogosText {
                objectName: root.objectPrefix + "AdvanceHint"
                visible: root.advanceHint.length > 0
                text: root.advanceHint
                color: Theme.palette.textTertiary
                font.pixelSize: Theme.typography.secondaryText
            }

            LogosButton {
                objectName: root.objectPrefix + "SecondaryButton"
                visible: root.secondaryText.length > 0
                Layout.preferredHeight: 44
                text: root.secondaryText
                onClicked: root.secondaryRequested()
            }

            LogosButton {
                objectName: root.objectPrefix + "AdvanceButton"
                variant: LogosButton.Variant.Primary
                Layout.preferredHeight: 44
                Layout.minimumWidth: 160
                enabled: root.canAdvance
                text: root.advanceText
                onClicked: root.advanceRequested()
            }
        }

        // Narrow: the way forward full width, Back and the second action below.
        ColumnLayout {
            visible: root.narrow
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                visible: root.advanceHint.length > 0
                Layout.fillWidth: true
                text: root.advanceHint
                color: Theme.palette.textTertiary
                font.pixelSize: Theme.typography.secondaryText
                wrapMode: Text.WordWrap
            }

            LogosButton {
                objectName: root.objectPrefix + "AdvanceButton"
                variant: LogosButton.Variant.Primary
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                enabled: root.canAdvance
                text: root.advanceText
                onClicked: root.advanceRequested()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.small

                LogosButton {
                    objectName: root.objectPrefix + "BackButton"
                    visible: root.canGoBack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    text: qsTr("Back")
                    onClicked: root.backRequested()
                }

                LogosButton {
                    objectName: root.objectPrefix + "SecondaryButton"
                    visible: root.secondaryText.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    text: root.secondaryText
                    onClicked: root.secondaryRequested()
                }
            }
        }
    }
}
