pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "OnboardingDefaults.js" as Defaults

// The last page: starts what was picked, shows how each one is
// doing, then the ways into the ecosystem. Storage is upstream's storage step,
// as is; the node, messaging and start-at-login are saved choices until
// startup services land (the spec, #107), and their lines say so.
ColumnLayout {
    id: root

    property string source: Defaults.downloadSource
    property bool storage: true
    property bool blockchain: false
    property bool messaging: false
    property bool login: false
    property string storageState: ""
    property string storageError: ""

    // The storage step decides when Open Basecamp is ready.
    readonly property bool done: !storage || storageStep.done
    readonly property bool failed: storage && storageStep.failed
    readonly property bool githubAllowed: storageStep.githubAllowed

    // What's next: the shell opens these once setup is gone.
    signal exploreAppsRequested()
    signal runNodeRequested()
    signal retryRequested()

    function enter() { if (storage) storageStep.enter() }
    function retry() { storageStep.retry() }

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("Starting Basecamp")
        color: Theme.palette.text
        font.pixelSize: 18
        font.weight: Theme.typography.weightBold
    }

    OnboardingStorageStep {
        id: storageStep
        objectName: "onboardingStorageStep"
        Layout.fillWidth: true
        visible: root.storage
        source: root.source
        storageState: root.storageState
        storageError: root.storageError
        onRetryRequested: root.retryRequested()
    }

    // The services this build can't start yet: what was picked, and when.
    Repeater {
        model: [
            { key: "blockchain", on: root.blockchain, name: qsTr("Blockchain node") },
            { key: "messaging",  on: root.messaging,  name: qsTr("Logos Messaging") },
            { key: "login",      on: root.login,      name: qsTr("Start when I log in") }
        ].filter(s => s.on)

        delegate: RowLayout {
            id: line
            required property var modelData
            objectName: "onboardingReady." + line.modelData.key
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            LogosText {
                Layout.fillWidth: true
                text: line.modelData.name
                color: Theme.palette.text
                font.pixelSize: Theme.typography.primaryText
            }
            LogosText {
                text: qsTr("Saved. Not started by this build yet.")
                color: Theme.palette.textTertiary
                font.pixelSize: Theme.typography.secondaryText
            }
        }
    }

    LogosText {
        Layout.topMargin: Theme.spacing.medium
        text: qsTr("What's next")
        color: Theme.palette.text
        font.pixelSize: Theme.typography.primaryText
        font.weight: Theme.typography.weightBold
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width < 640 ? 1 : 3
        columnSpacing: Theme.spacing.medium
        rowSpacing: Theme.spacing.medium

        OnboardingChoiceCard {
            objectName: "onboardingNextApps"
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: qsTr("Explore apps")
            description: qsTr("See what you can install and run today.")
            onPicked: root.exploreAppsRequested()
        }

        OnboardingChoiceCard {
            objectName: "onboardingNextNode"
            visible: !root.blockchain
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: qsTr("Run a node")
            description: qsTr("Join the Logos testnet from Basecamp and earn your first tokens.")
            onPicked: root.runNodeRequested()
        }

        LogosFrame {
            objectName: "onboardingNextBuild"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            radius: Theme.spacing.radiusLarge
            backgroundColor: Theme.palette.surfaceRaised
            borderColor: Theme.palette.border

            contentItem: ColumnLayout {
                spacing: 4

                LogosText {
                    text: qsTr("Build an app")
                    color: Theme.palette.text
                    font.pixelSize: Theme.typography.primaryText
                    font.weight: Theme.typography.weightBold
                }
                LogosText {
                    Layout.fillWidth: true
                    text: qsTr("Make your own Basecamp app and share it with the community.")
                    color: Theme.palette.textSecondary
                    font.pixelSize: Theme.typography.secondaryText
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    spacing: Theme.spacing.small
                    LogosText {
                        text: qsTr("Copy the guide link")
                        color: Theme.palette.textSecondary
                        font.pixelSize: Theme.typography.secondaryText
                    }
                    LogosCopyButton {
                        objectName: "onboardingNextBuildCopy"
                        value: Defaults.buildDocs.app
                        feedbackText: qsTr("Link copied")
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
