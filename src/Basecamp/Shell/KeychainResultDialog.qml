import QtQuick
import QtQuick.Controls
import Logos.Controls
import Logos.Theme

// Signed / Not signed (basecamp-experiments#58): the shell's own sheet over
// the app that asked Keychain for a signature, once the request ends. The
// host has already brought that app forward (MainUIBackend, on
// KeychainBroker::requestFinished); the app gets the result itself as the
// answer to its basecamp.keychain.sign.
//
// The shell says it, not the app: an app could draw "Signed" over anything.
// What the signer gave as a reason for saying no is its own words, and shown
// as such.
IntentDialog {
    id: root

    objectName: "keychainResultDialog"

    property var displayNameLookup: function (name) { return name }

    // KeychainBroker::requestFinished's summary: { requestId, status, error?,
    // reason?, signerApp?, signerName?, keyName? }.
    property var summary: ({})
    property string requester: ""

    readonly property bool signed: summary.status === "done"
    readonly property string requesterName: requester ? displayNameLookup(requester) : ""
    readonly property string signerName: summary.signerName || summary.signerApp || ""

    function openWith(requesterApp, result) {
        requester = requesterApp || ""
        summary = result || ({})
        open()
    }

    // Close only if this is still the one on screen.
    function closeFor(requestId) {
        if (visible && summary.requestId === requestId) close()
    }

    function statusText() {
        switch (summary.status) {
        case "done":      return qsTr("Signed")
        case "rejected":  return qsTr("Not signed: rejected")
        case "cancelled": return qsTr("Not signed: cancelled")
        case "timedOut":  return qsTr("Not signed: timed out")
        default:          return qsTr("Not signed: failed")
        }
    }

    function detailText() {
        const e = summary.error || ""
        if (signed)
            return qsTr("%1 signed it with %2.").arg(signerName).arg(summary.keyName || qsTr("its key"))
        if (summary.status === "rejected")
            return qsTr("%1 said no.").arg(signerName)
        if (e === "keychain_closed")
            return qsTr("Keychain was closed before a key was chosen.")
        if (summary.status === "cancelled")
            return qsTr("You cancelled it in Keychain.")
        if (summary.status === "timedOut")
            return qsTr("Nothing was decided within 5 minutes.")
        if (e === "bad_signature")
            return qsTr("The signature from %1 did not match its key, so it was not passed on.").arg(signerName)
        if (e === "signer_closed")
            return qsTr("%1 was closed before it answered.").arg(signerName)
        if (e === "signer_unavailable")
            return qsTr("%1 could not take the request.").arg(signerName || qsTr("The signing app"))
        if (e === "key_removed")
            return qsTr("The key was removed from Keychain while it was signing.")
        return qsTr("Something went wrong while signing.")
    }

    title: statusText()
    width: Math.min(480, (parent ? parent.width : 480) - 32)

    contentItem: Column {
        spacing: Theme.spacing.small
        LogosText {
            objectName: "keychainResultDialog.requester"
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.palette.textSecondary
            font.pixelSize: Theme.typography.secondaryText
            text: qsTr("%1 asked for a signature.").arg(root.requesterName)
        }
        LogosText {
            objectName: "keychainResultDialog.detail"
            width: parent.width
            wrapMode: Text.Wrap
            text: root.detailText()
        }
        LogosText {
            objectName: "keychainResultDialog.reason"
            visible: !root.signed && (root.summary.reason || "") !== ""
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: Theme.palette.textSecondary
            text: qsTr("%1 says: “%2”").arg(root.signerName).arg(root.summary.reason || "")
        }
    }

    rightActions: [
        LogosButton {
            objectName: "keychainResultDialog.ok"
            text: qsTr("OK")
            variant: LogosButton.Variant.Primary
            onClicked: root.close()
        }
    ]
}
