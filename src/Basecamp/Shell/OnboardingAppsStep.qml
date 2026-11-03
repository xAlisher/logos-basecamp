pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "OnboardingDefaults.js" as Defaults

// Custom setup, Apps: which catalogs apps come from, then upstream's download
// choice below them. Nothing is applied here; OnboardingShell
// applies the choices when the last page finishes.
ColumnLayout {
    id: root

    property bool official: Defaults.officialCatalog
    property bool community: Defaults.communityCatalog
    readonly property string communityUrl: Defaults.communityCatalogUrl
    readonly property bool communityAvailable: communityUrl.length > 0

    // From the download choice below.
    readonly property bool github: downloads.github
    readonly property bool storage: downloads.storage
    readonly property string source: downloads.source
    readonly property bool valid: (official || community) && downloads.valid
    readonly property string hint: !(official || community) ? qsTr("Pick at least one catalog")
                                                            : downloads.hint

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("Where your apps come from")
        color: Theme.palette.text
        font.pixelSize: 18
        font.weight: Theme.typography.weightBold
    }

    LogosText {
        Layout.fillWidth: true
        Layout.topMargin: -Theme.spacing.small
        text: qsTr("Basecamp installs apps from catalogs, and downloads them over the internet or the Logos network.")
        color: Theme.palette.textSecondary
        font.pixelSize: Theme.typography.secondaryText
        wrapMode: Text.WordWrap
    }

    LogosText {
        Layout.topMargin: Theme.spacing.small
        text: qsTr("Catalogs")
        color: Theme.palette.text
        font.pixelSize: Theme.typography.primaryText
        font.weight: Theme.typography.weightBold
    }

    OnboardingChoiceCard {
        objectName: "onboardingOfficialCatalogCard"
        multi: true
        title: qsTr("Logos official")
        description: qsTr("Apps published by Logos.")
        selected: root.official
        onPicked: root.official = !root.official
    }

    OnboardingChoiceCard {
        objectName: "onboardingCommunityCatalogCard"
        multi: true
        enabled: root.communityAvailable
        opacity: enabled ? 1 : 0.6
        title: qsTr("Community catalog")
        badge: qsTr("Not reviewed by Logos")
        badgeColor: Theme.palette.warning
        description: root.communityAvailable
            ? qsTr("Apps anyone can list, without permission. Logos doesn't review or endorse them: check who published an app before you install it.")
            : qsTr("Apps anyone can list, without permission. Not available in this build yet.")
        selected: root.community && root.communityAvailable
        onPicked: root.community = !root.community
    }

    OnboardingDownloadsStep {
        id: downloads
        objectName: "onboardingDownloadsStep"
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.medium
    }
}
