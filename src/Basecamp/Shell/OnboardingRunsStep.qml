pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "OnboardingDefaults.js" as Defaults

// Custom setup, What runs on this computer: the services that
// start with Basecamp, and whether Basecamp starts at login. Storage is locked
// on when apps download through Logos Storage. Only storage is wired in this
// build; the others are saved for startup services (the spec, #107).
ColumnLayout {
    id: root

    // Storage downloads were picked on the Apps page.
    property bool storageRequired: true

    property bool storage: Defaults.services.storage
    property bool blockchain: Defaults.services.blockchain
    property bool messaging: Defaults.services.messaging
    property bool login: Defaults.services.login

    readonly property bool storageOn: storage || storageRequired

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("What runs on this computer")
        color: Theme.palette.text
        font.pixelSize: 18
        font.weight: Theme.typography.weightBold
    }

    LogosText {
        Layout.fillWidth: true
        Layout.topMargin: -Theme.spacing.small
        text: qsTr("These start with Basecamp and keep running while it's open. Each one uses this computer's resources and connects to the network.")
        color: Theme.palette.textSecondary
        font.pixelSize: Theme.typography.secondaryText
        wrapMode: Text.WordWrap
    }

    OnboardingChoiceCard {
        objectName: "onboardingRunsStorageCard"
        multi: true
        enabled: !root.storageRequired
        title: qsTr("Logos Storage")
        badge: root.storageRequired ? qsTr("Needed for Logos Storage downloads") : ""
        badgeColor: Theme.palette.textTertiary
        description: qsTr("Downloads apps from the Logos network and shares them with others. Uses some disk and bandwidth.")
        selected: root.storageOn
        onPicked: root.storage = !root.storage
    }

    OnboardingChoiceCard {
        objectName: "onboardingRunsBlockchainCard"
        multi: true
        title: qsTr("Blockchain node")
        description: qsTr("Joins the Logos testnet and can earn first tokens through Proof-of-Work. Uses disk and CPU while it syncs.")
        selected: root.blockchain
        onPicked: root.blockchain = !root.blockchain
    }

    OnboardingChoiceCard {
        objectName: "onboardingRunsMessagingCard"
        multi: true
        title: qsTr("Logos Messaging")
        description: qsTr("A messaging node, so chat and other apps can reach people directly. Uses some bandwidth.")
        selected: root.messaging
        onPicked: root.messaging = !root.messaging
    }

    LogosText {
        Layout.topMargin: Theme.spacing.small
        text: qsTr("Basecamp itself")
        color: Theme.palette.text
        font.pixelSize: Theme.typography.primaryText
        font.weight: Theme.typography.weightBold
    }

    OnboardingChoiceCard {
        objectName: "onboardingRunsLoginCard"
        multi: true
        title: qsTr("Start Basecamp when I log in")
        description: qsTr("Opens in the background, with the services above, each time you log in to this computer.")
        selected: root.login
        onPicked: root.login = !root.login
    }

    LogosText {
        Layout.fillWidth: true
        text: qsTr("You can change this later in Settings.")
        color: Theme.palette.textTertiary
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }
}
