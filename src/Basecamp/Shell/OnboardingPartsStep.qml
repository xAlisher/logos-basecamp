pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import Basecamp.Backend 1.0

import "OnboardingDefaults.js" as Defaults

// Custom setup, Parts: every replaceable part of Basecamp, who
// made the one in use, another to pick, and a link to build your own. Choices
// are staged in `picks` and applied by OnboardingShell on the last page; only
// the theme changes at once, as its own preview, and goes back on Keep all.
//
// `roles` is backend.roles, `candidates(role)` backend.roleCandidates, and
// `prefs` the shell's preferences (shells); any may be missing in a host
// without them, and the rows for it are left out.
ColumnLayout {
    id: root

    property var roles: ({})
    property var candidates: function (role) { return [] }
    property var prefs: null

    // part -> chosen id; a part not in here keeps what it has.
    property var picks: ({})
    readonly property string originalTheme: d.originalTheme

    function keepAll() {
        picks = ({})
        if (Theme.currentTheme !== d.originalTheme)
            Theme.setTheme(d.originalTheme)
    }

    function pick(part, id) {
        const next = Object.assign({}, picks)
        next[part] = id
        picks = next
        if (part === "theme")
            Theme.setTheme(id)
    }

    QtObject {
        id: d
        property string originalTheme: ""
        Component.onCompleted: originalTheme = Theme.currentTheme

        readonly property var roleText: ({
            launcher: { label: qsTr("Applications"), hint: qsTr("Lists your apps and opens them.") },
            home:     { label: qsTr("Home"),         hint: qsTr("The first page you see, and what apps share with you.") },
            search:   { label: qsTr("Search"),       hint: qsTr("Ranks what apps share when you search. With none, Basecamp ranks by itself.") },
            packages: { label: qsTr("Packages"),     hint: qsTr("Installs, updates and removes apps. Whichever app you choose may ask to uninstall or downgrade packages."), warn: true },
            settings: { label: qsTr("Settings"),     hint: qsTr("The app you choose can change Basecamp's preferences and default apps."), warn: true },
            keychain: { label: qsTr("Keychain"),     hint: qsTr("Lists your public keys and asks which key signs. The app you choose sees every key, your labels and notes, and every signing request."), warn: true }
        })

        function themeOptions() {
            const info = Theme.themeInfo
            return Object.keys(info).map(id => ({
                id: id, name: info[id].name + (info[id].author ? " · " + qsTr("by %1").arg(info[id].author) : "")
            }))
        }

        function shellOptions() {
            if (!root.prefs || !root.prefs.shellPackages) return []
            return root.prefs.shellPackages.map(s => ({
                id: s.id, name: s.name + (s.author ? " · " + qsTr("by %1").arg(s.author) : "")
            }))
        }

        function roleOptions(role) {
            const list = (root.candidates(role) || []).map(c => ({
                id: c.name, name: c.displayName + (c.isDefault ? " · " + qsTr("by Logos") : "")
            }))
            if (role === "search")
                list.push({ id: "", name: qsTr("None (Basecamp ranks by itself)") })
            return list
        }

        // The rows, in order: shell and theme first, then the roles.
        readonly property var rows: {
            root.roles   // re-read when roles change hands
            const out = []
            const shells = shellOptions()
            if (shells.length > 0)
                out.push({ part: "shell", label: qsTr("Shell"), hint: qsTr("Everything around your apps: how they open, the bars, the home. Changing it restarts Basecamp."),
                           options: shells, current: root.prefs.shell, docs: Defaults.buildDocs.shell, upload: "lgx" })
            out.push({ part: "theme", label: qsTr("Theme"), hint: qsTr("Colours, type and icons. Applies now, so you can see it."),
                       options: themeOptions(), current: d.originalTheme, docs: Defaults.buildDocs.theme, upload: "theme" })
            if (root.roles) {
                for (const role of Defaults.roles) {
                    const options = roleOptions(role)
                    if (options.length === 0) continue
                    out.push({ part: role, label: roleText[role].label, hint: roleText[role].hint, warn: roleText[role].warn === true,
                               options: options, current: root.roles[role] || "", docs: Defaults.buildDocs[role], upload: "lgx" })
                }
            }
            return out
        }
    }

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("Basecamp is made of parts")
        color: Theme.palette.text
        font.pixelSize: 18
        font.weight: Theme.typography.weightBold
    }

    LogosText {
        Layout.fillWidth: true
        Layout.topMargin: -Theme.spacing.small
        text: qsTr("Each part is Logos's default and can be replaced. Pick another one, upload your own, or build one.")
        color: Theme.palette.textSecondary
        font.pixelSize: Theme.typography.secondaryText
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: d.rows

        delegate: LogosFrame {
            id: row
            required property var modelData
            readonly property string chosen: root.picks[modelData.part] !== undefined
                                             ? root.picks[modelData.part] : modelData.current
            objectName: "onboardingPart." + modelData.part
            Layout.fillWidth: true
            radius: Theme.spacing.radiusLarge
            backgroundColor: Theme.palette.surfaceRaised
            borderColor: Theme.palette.border

            contentItem: ColumnLayout {
                spacing: Theme.spacing.small

                GridLayout {
                    Layout.fillWidth: true
                    // Narrow windows stack the name above the picker.
                    columns: root.width < 520 ? 1 : 2
                    columnSpacing: Theme.spacing.medium
                    rowSpacing: Theme.spacing.small

                    LogosText {
                        Layout.preferredWidth: 120
                        text: row.modelData.label
                        color: Theme.palette.text
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightBold
                    }

                    LogosComboBox {
                        objectName: "onboardingPart." + row.modelData.part + ".picker"
                        Layout.fillWidth: true
                        model: row.modelData.options
                        textRole: "name"
                        valueRole: "id"
                        currentIndex: row.modelData.options.findIndex(o => o.id === row.chosen)
                        onActivated: index => root.pick(row.modelData.part, row.modelData.options[index].id)
                    }
                }

                LogosText {
                    Layout.fillWidth: true
                    text: row.modelData.hint
                    color: row.modelData.warn && row.chosen !== row.modelData.current
                           ? Theme.palette.warning : Theme.palette.textSecondary
                    font.pixelSize: Theme.typography.secondaryText
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    LogosButton {
                        objectName: "onboardingPart." + row.modelData.part + ".upload"
                        text: qsTr("Upload…")
                        onClicked: root.upload(row.modelData)
                    }

                    Item { Layout.fillWidth: true }

                    LogosText {
                        text: qsTr("Build your own")
                        color: Theme.palette.textSecondary
                        font.pixelSize: Theme.typography.secondaryText
                    }

                    LogosCopyButton {
                        objectName: "onboardingPart." + row.modelData.part + ".docs"
                        value: row.modelData.docs
                        feedbackText: qsTr("Link copied")
                    }
                }
            }
        }
    }

    LogosNotice {
        id: uploadNotice
        objectName: "onboardingPartsNotice"
        Layout.fillWidth: true
        visible: false
    }

    LogosText {
        Layout.fillWidth: true
        text: qsTr("Nothing changes until you finish. You can change these later in Settings › Customisation and Settings › Default apps.")
        color: Theme.palette.textTertiary
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }

    // Upload: a theme file installs here and is picked; a shell or an app is
    // an .lgx, and installs go through Package Manager and its confirm dialog,
    // which isn't up during setup, so the notice says where.
    Connections {
        target: root
        function onVisibleChanged() { if (!root.visible) uploadNotice.visible = false }
    }
    function _uploadTheme() {
        if (!root.prefs) return
        const f = root.prefs.pickFile(qsTr("Choose a theme"), qsTr("Logos theme (*.json)"))
        if (f.toString().length === 0) return
        const r = ThemeInstaller.install(f)
        uploadNotice.visible = true
        if (r.ok) {
            ThemeRegistry.reload()
            root.pick("theme", r.id)
            uploadNotice.severity = LogosNotice.Success
            uploadNotice.title = qsTr("Installed “%1”").arg(r.name)
            uploadNotice.message = ""
        } else {
            uploadNotice.severity = LogosNotice.Error
            uploadNotice.title = qsTr("That file isn't a valid theme")
            uploadNotice.message = r.errors.join("; ")
        }
    }
    function upload(rowData) {
        if (rowData.upload === "theme") {
            root._uploadTheme()
            return
        }
        uploadNotice.severity = LogosNotice.Info
        uploadNotice.title = qsTr("Install it after setup")
        uploadNotice.message = qsTr("%1 come as .lgx packages. After setup, open Package Manager, choose Install Local Package, then pick it in Settings.")
                               .arg(rowData.part === "shell" ? qsTr("Shells") : qsTr("Apps"))
        uploadNotice.visible = true
    }
}
