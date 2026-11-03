.pragma library

// What Quick start sets up, and where every Custom setup page starts. One list
// read by the Quick start sheet and the pages, so the sheet can't drift from
// what Quick start does.

// package_downloader's download source for "GitHub and Logos Storage".
var downloadSource = "any"

// Catalogs. The community catalog is opt-in and not reviewed by Logos; empty
// until one exists, and the row says so.
var officialCatalog = true
var communityCatalog = false
var communityCatalogUrl = ""

// What runs on this computer. Storage follows the download
// source; the rest are off.
var services = {
    storage: true,
    blockchain: false,
    messaging: false,
    login: false
}

// Roles shown on the Parts page, in order. Each keeps the app
// that fills it now unless the user picks another.
var roles = [ "launcher", "home", "search", "packages", "settings", "keychain" ]

// The docs page each part's "Build your own" copies. Theme, shell and search
// point where their pages will live; they aren't written yet.
var buildDocs = {
    app:      "https://docs.logos.co/build-an-app",
    shell:    "https://docs.logos.co/basecamp/build-a-shell",
    theme:    "https://docs.logos.co/basecamp/build-a-theme",
    launcher: "https://docs.logos.co/build-an-app",
    home:     "https://docs.logos.co/build-an-app",
    search:   "https://docs.logos.co/basecamp/build-a-search-app",
    packages: "https://docs.logos.co/build-an-app",
    settings: "https://docs.logos.co/build-an-app",
    keychain: "https://docs.logos.co/build-an-app"
}

function summary() {
    return [
        { label: qsTr("Apps from"),          value: qsTr("Logos official catalog") },
        { label: qsTr("Downloads via"),      value: qsTr("GitHub and Logos Storage") },
        { label: qsTr("Runs on this computer"), value: qsTr("Logos Storage") },
        { label: qsTr("Off"),                value: qsTr("Blockchain node, Logos Messaging, start at login") },
        { label: qsTr("Parts"),              value: qsTr("All by Logos") }
    ]
}
