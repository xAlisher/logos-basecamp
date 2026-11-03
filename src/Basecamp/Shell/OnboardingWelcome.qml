pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

// First-run landing: what Basecamp is, then the two ways in.
// The words follow logos.co/basecamp; "Modular" is shown only where parts can
// really be swapped (`modular`).
Item {
    id: root

    property url backdrop
    property url logo
    property bool modular: true

    signal quickSetupRequested()
    signal quickSetupDetailsRequested()
    signal customSetupRequested()

    Image {
        anchors.fill: parent
        source: root.backdrop
        fillMode: Image.PreserveAspectCrop
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.palette.scrim
    }

    LogosScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        Item {
            width: scroll.availableWidth
            height: Math.max(scroll.availableHeight, column.implicitHeight + 2 * Theme.spacing.xlarge)

            ColumnLayout {
                id: column
                objectName: "onboardingWelcomeColumn"
                anchors.centerIn: parent
                width: Math.min(parent.width - 2 * Theme.spacing.large, 560)
                spacing: Theme.spacing.medium

                Image {
                    objectName: "onboardingLogo"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: Theme.spacing.small
                    source: root.logo
                    sourceSize.height: 48
                    fillMode: Image.PreserveAspectFit
                }

                LogosText {
                    objectName: "onboardingGreeting"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Welcome to Logos Basecamp")
                    color: Theme.palette.text
                    font.pixelSize: Theme.typography.pageTitleText
                    font.weight: Theme.typography.weightBold
                    wrapMode: Text.WordWrap
                }

                LogosText {
                    objectName: "onboardingTagline"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("A local-first launcher for peer-to-peer apps built on Logos.\n"
                               + "No cloud. No accounts. Private by default.")
                    color: Theme.palette.text
                    font.pixelSize: Theme.typography.subtitleText
                    wrapMode: Text.WordWrap
                }

                LogosFrame {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.medium
                    radius: Theme.spacing.radiusLarge
                    backgroundColor: Theme.palette.surfaceRaised
                    borderColor: Theme.palette.border

                    contentItem: ColumnLayout {
                        spacing: Theme.spacing.medium

                        Repeater {
                            model: [
                                { key: "local", title: qsTr("Local-first"),
                                  text: qsTr("Your keys, data and activity stay on this machine. You are the infrastructure.") },
                                { key: "p2p", title: qsTr("Peer-to-peer"),
                                  text: qsTr("Apps connect to other people directly, not through a server.") },
                                { key: "modular", title: qsTr("Modular"),
                                  text: qsTr("Every part of Basecamp can be replaced: the apps, the search, even the shell you're looking at. Pick what you like, or build your own.") }
                            ].filter(p => p.key !== "modular" || root.modular)

                            delegate: ColumnLayout {
                                id: pillar
                                required property var modelData
                                objectName: "onboardingPillar." + pillar.modelData.key
                                Layout.fillWidth: true
                                spacing: 2

                                LogosText {
                                    text: pillar.modelData.title
                                    color: Theme.palette.text
                                    font.pixelSize: Theme.typography.primaryText
                                    font.weight: Theme.typography.weightBold
                                }
                                LogosText {
                                    Layout.fillWidth: true
                                    text: pillar.modelData.text
                                    color: Theme.palette.textSecondary
                                    font.pixelSize: Theme.typography.secondaryText
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                LogosText {
                    objectName: "onboardingTestnetNote"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("This is testnet software. Apps are experimental and things will change.")
                    color: Theme.palette.textSecondary
                    font.pixelSize: Theme.typography.secondaryText
                    wrapMode: Text.WordWrap
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.spacing.medium
                    Layout.preferredWidth: Math.min(320, column.width)
                    spacing: Theme.spacing.small

                    LogosButton {
                        objectName: "onboardingQuickSetupButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        variant: LogosButton.Variant.Primary
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        text: qsTr("Quick start")
                        onClicked: root.quickSetupRequested()
                    }

                    LogosText {
                        objectName: "onboardingQuickSetupDetails"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 32
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("See what Quick start sets up")
                        color: Theme.palette.text
                        font.pixelSize: Theme.typography.secondaryText
                        font.underline: true

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.quickSetupDetailsRequested()
                        }
                    }

                    LogosButton {
                        objectName: "onboardingCustomSetupButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        text: qsTr("Custom setup")
                        onClicked: root.customSetupRequested()

                        background: Rectangle {
                            readonly property var control: parent

                            radius: control.radius
                            color: control.pressed  ? Theme.palette.background
                                 : control.hovered  ? Theme.palette.backgroundTertiary
                                                    : Theme.palette.backgroundSecondary
                            border.width: 1
                            border.color: Theme.palette.border
                        }
                    }
                }
            }
        }
    }
}
