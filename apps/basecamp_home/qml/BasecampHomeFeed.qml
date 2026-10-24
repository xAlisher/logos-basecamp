import QtQuick

import Logos.Controls
import Logos.Theme
import Basecamp.Objects

import "BasecampHomeModules.js" as M

// Home's feed (SHELL-OBJECTS-SPEC §7): every object the bar and the pill
// leave, newest first, one card each, with how many are new since the user
// last looked. Grows with its rows; the page around it scrolls.
Column {
    id: feed

    // Envelopes, newest first (M.feedRows).
    property var rows: []
    property real now: Date.now()
    property var newIds: ({})
    // When the previous visit started (0: this is the first).
    property real since: 0
    // Cards drawn at once; "Show more" adds a page.
    property int shown: 30

    signal raiseRequested(string id, string action, string text)

    readonly property int newCount: M.newCount(feed.rows, feed.newIds)

    objectName: "home.feed"
    spacing: Theme.spacing.small

    LogosText {
        objectName: "home.feed.newSince"
        width: parent.width
        text: feed.newCount === 0
              ? (feed.rows.length === 0 ? "" : qsTr("Nothing new"))
              : feed.since > 0 ? qsTr("%1 new since %2").arg(feed.newCount).arg(ObjectCardFormat.clock(feed.since))
                               : qsTr("%1 new").arg(feed.newCount)
        visible: text.length > 0
        color: feed.newCount > 0 ? Theme.palette.accentOrange : Theme.palette.textTertiary
        font.pixelSize: Theme.typography.secondaryText
        font.weight: Theme.typography.weightMedium
    }

    Repeater {
        model: feed.rows.slice(0, feed.shown)
        delegate: ObjectCard {
            required property var modelData
            width: feed.width
            object: modelData
            now: feed.now
            isNew: feed.newIds[modelData.id] === true
            namePrefix: "home.card." + modelData.key
            onActionRequested: (action, text) => feed.raiseRequested(modelData.id, action, text)
        }
    }

    LogosButton {
        objectName: "home.feed.more"
        visible: feed.rows.length > feed.shown
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTr("Show more (%1)").arg(feed.rows.length - feed.shown)
        onClicked: feed.shown += 30
    }
}
