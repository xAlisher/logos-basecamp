import QtQuick
import QtCore

import Logos.Theme
import Logos.Icons
import Basecamp.Icons

// Root of the first-run onboarding layer, which covers the window until the
// user has finished setup. The only onboarding file that reaches the backend:
// the views below emit signals, and the choices are applied here, once, when
// the last page finishes.
Rectangle {
    id: root

    signal finished()

    color: Theme.palette.background

    // What runs on this computer, for startup services (the spec, #107) to
    // read. Storage already follows the download source.
    Settings {
        id: startupServices
        category: "startupServices"
        property bool storage: true
        property bool blockchain: false
        property bool messaging: false
        property bool login: false
    }

    // Set by the shell: its preferences (shells, restart), when it has them.
    readonly property var prefs: typeof shellPrefs !== "undefined" ? shellPrefs : null
    readonly property bool modular: typeof backend.roleCandidates === "function"

    function apply(choices) {
        const c = choices.catalogs
        if (c.community && c.communityUrl.length > 0)
            backend.addRepository(c.communityUrl)
        if (!c.official) {
            // A fresh profile holds only the official catalog; turn off what's there.
            for (const r of (backend.repositories || []))
                if (r.url && r.url !== c.communityUrl)
                    backend.setRepositoryEnabled(r.url, false)
        }

        startupServices.storage = choices.services.storage
        startupServices.blockchain = choices.services.blockchain
        startupServices.messaging = choices.services.messaging
        startupServices.login = choices.services.login

        let restart = false
        for (const part in choices.parts) {
            const id = choices.parts[part]
            if (part === "theme") {
                Theme.setTheme(id)       // already showing; this keeps it
            } else if (part === "shell") {
                if (root.prefs && id !== root.prefs.shell) {
                    root.prefs.shell = id
                    restart = true
                }
            } else if (id !== (backend.roles[part] || "")) {
                backend.assignRole(part, id)
            }
        }
        return restart
    }

    OnboardingView {
        objectName: "onboardingView"
        anchors.fill: parent
        backdrop: LogosIcons.onboardingBackdrop
        logo: BasecampIcons.logo
        storageState: backend.storageState
        storageError: backend.storageError
        modular: root.modular
        roles: root.modular ? backend.roles : ({})
        roleCandidates: function (role) { return root.modular ? backend.roleCandidates(role) : [] }
        prefs: root.prefs
        onSourceChosen: (source) => backend.chooseOnboardingSource(source)
        onRetryStorageRequested: backend.retryStorage()
        onFinished: (choices) => {
            const restart = root.apply(choices)
            backend.completeOnboarding()
            root.finished()
            if (restart) {
                root.prefs.restart()
                return
            }
            if (choices.next === "apps")
                backend.openRole("launcher")
            else if (choices.next === "node")
                backend.openApp("blockchain_ui", "", ({}), true)
        }
    }
}
