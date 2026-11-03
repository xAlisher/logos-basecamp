pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "OnboardingDefaults.js" as Defaults

// First-run onboarding: Welcome, then Custom setup's Apps, What
// runs, Parts and Ready, or Quick start straight to Ready with the defaults.
// Nothing is final until Ready: going back and choosing again just changes the
// choice. `finished(choices)` hands everything to OnboardingShell to apply.
Item {
    id: root

    // --- Inputs from the host ---

    property string storageState: ""
    property string storageError: ""
    property url backdrop
    property url logo
    // Where parts can be swapped (role apps, shells): the Welcome page's
    // Modular line and the Parts page show only then.
    property bool modular: false
    property var roles: ({})
    property var roleCandidates: function (role) { return [] }
    property var prefs: null

    // --- Outputs ---

    // The download source is chosen: "any", "logos" or "http".
    signal sourceChosen(string source)
    signal retryStorageRequested()
    // { catalogs: { official, community, communityUrl }, services: {...},
    //   parts: { part: id }, next: "" | "apps" | "node" }
    signal finished(var choices)

    QtObject {
        id: d

        property string source: ""
        property int stepIndex: -1
        property bool quick: false
        property bool sheetOpen: false
        property string next: ""

        readonly property var steps: quick ? ["ready"]
                                           : (root.modular ? ["apps", "runs", "parts", "ready"]
                                                           : ["apps", "runs", "ready"])

        readonly property string step: (stepIndex >= 0 && stepIndex < steps.length)
            ? steps[stepIndex]
            : "welcome"

        readonly property var stepNames: steps.map(function (name) {
            switch (name) {
            case "apps":  return qsTr("Apps")
            case "runs":  return qsTr("What runs")
            case "parts": return qsTr("Parts")
            case "ready": return qsTr("Ready")
            default:      return name
            }
        })

        // Quick start uses the defaults, not whatever the pages hold.
        readonly property bool storageDownloads: quick ? Defaults.downloadSource !== "http"
                                                       : appsStep.storage

        function choose(source) {
            if (source === d.source) return
            d.source = source
            root.sourceChosen(source)
        }

        function quickStart() {
            d.sheetOpen = false
            d.quick = true
            partsStep.keepAll()
            d.choose(Defaults.downloadSource)
            d.stepIndex = 0
            readyStep.enter()
        }

        function customSetup() {
            d.quick = false
            d.stepIndex = 0
        }

        readonly property bool canGoBack: step !== "welcome"

        function back() {
            if (d.quick || d.stepIndex === 0) {
                d.quick = false
                d.stepIndex = -1
                return
            }
            d.stepIndex = d.stepIndex - 1
        }

        function advance() {
            switch (step) {
            case "apps":
                d.choose(appsStep.source)
                break
            case "ready":
                root.finished(d.choices())
                return
            }
            d.stepIndex = d.stepIndex + 1
            if (step === "ready")
                readyStep.enter()
        }

        function choices() {
            if (d.quick) {
                return {
                    catalogs: { official: Defaults.officialCatalog, community: Defaults.communityCatalog,
                                communityUrl: Defaults.communityCatalogUrl },
                    services: Object.assign({}, Defaults.services),
                    parts: ({}),
                    next: d.next
                }
            }
            return {
                catalogs: { official: appsStep.official, community: appsStep.community && appsStep.communityAvailable,
                            communityUrl: appsStep.communityUrl },
                services: { storage: runsStep.storageOn, blockchain: runsStep.blockchain,
                            messaging: runsStep.messaging, login: runsStep.login },
                parts: root.modular ? partsStep.picks : ({}),
                next: d.next
            }
        }

        readonly property bool canAdvance: {
            switch (step) {
            case "apps":  return appsStep.valid
            case "ready": return readyStep.done
            default:      return true
            }
        }

        readonly property string advanceHint: step === "apps" ? appsStep.hint : ""

        readonly property string advanceText: {
            if (step !== "ready")
                return qsTr("Continue")
            if (!readyStep.done)
                return qsTr("Starting…")
            return readyStep.failed && !readyStep.githubAllowed
                ? qsTr("Continue without downloads")
                : qsTr("Open Basecamp")
        }
    }

    // One page at a time: the welcome screen, then each setup step.
    StackLayout {
        objectName: "onboardingPages"
        anchors.fill: parent
        currentIndex: {
            switch (d.step) {
            case "apps":  return 1
            case "runs":  return 2
            case "parts": return 3
            case "ready": return 4
            default:      return 0
            }
        }

        OnboardingWelcome {
            objectName: "onboardingWelcome"
            backdrop: root.backdrop
            logo: root.logo
            modular: root.modular
            onQuickSetupRequested: d.quickStart()
            onQuickSetupDetailsRequested: d.sheetOpen = true
            onCustomSetupRequested: d.customSetup()
        }

        OnboardingStepPage {
            objectPrefix: "onboardingApps"
            stepNames: d.stepNames
            stepIndex: d.stepIndex
            canGoBack: d.canGoBack
            canAdvance: d.canAdvance
            advanceText: d.advanceText
            advanceHint: d.advanceHint
            onBackRequested: d.back()
            onAdvanceRequested: d.advance()

            OnboardingAppsStep {
                id: appsStep
                objectName: "onboardingAppsStep"
                anchors.fill: parent
            }
        }

        OnboardingStepPage {
            objectPrefix: "onboardingRuns"
            stepNames: d.stepNames
            stepIndex: d.stepIndex
            canGoBack: d.canGoBack
            canAdvance: d.canAdvance
            advanceText: d.advanceText
            onBackRequested: d.back()
            onAdvanceRequested: d.advance()

            OnboardingRunsStep {
                id: runsStep
                objectName: "onboardingRunsStep"
                anchors.fill: parent
                storageRequired: appsStep.storage
            }
        }

        OnboardingStepPage {
            objectPrefix: "onboardingParts"
            stepNames: d.stepNames
            stepIndex: d.stepIndex
            canGoBack: d.canGoBack
            canAdvance: d.canAdvance
            advanceText: d.advanceText
            secondaryText: qsTr("Keep all")
            onSecondaryRequested: {
                partsStep.keepAll()
                d.advance()
            }
            onBackRequested: d.back()
            onAdvanceRequested: d.advance()

            OnboardingPartsStep {
                id: partsStep
                objectName: "onboardingPartsStep"
                anchors.fill: parent
                roles: root.roles
                candidates: root.roleCandidates
                prefs: root.prefs
            }
        }

        OnboardingStepPage {
            objectPrefix: "onboardingReady"
            subtitle: d.quick ? qsTr("Quick start: the defaults, ready in a moment.") : qsTr("Custom setup: last step.")
            stepNames: d.stepNames
            stepIndex: d.stepIndex
            canGoBack: d.canGoBack
            canAdvance: d.canAdvance
            advanceText: d.advanceText
            onBackRequested: d.back()
            onAdvanceRequested: d.advance()
            secondaryText: readyStep.failed ? qsTr("Retry") : ""
            onSecondaryRequested: readyStep.retry()

            OnboardingReadyStep {
                id: readyStep
                objectName: "onboardingReadyStep"
                anchors.fill: parent
                source: d.source.length > 0 ? d.source : Defaults.downloadSource
                storage: d.storageDownloads
                blockchain: !d.quick && runsStep.blockchain
                messaging: !d.quick && runsStep.messaging
                login: !d.quick && runsStep.login
                storageState: root.storageState
                storageError: root.storageError
                onRetryRequested: root.retryStorageRequested()
                onExploreAppsRequested: { d.next = "apps"; if (readyStep.done) root.finished(d.choices()) }
                onRunNodeRequested:     { d.next = "node"; if (readyStep.done) root.finished(d.choices()) }
            }
        }
    }

    OnboardingQuickStartSheet {
        objectName: "onboardingQuickStart"
        anchors.fill: parent
        visible: d.sheetOpen
        onStartRequested: d.quickStart()
        onCloseRequested: d.sheetOpen = false
    }
}
