import QtQuick
import QtQuick.Controls

import Logos.Theme
import Logos.Controls
import Logos.Icons
import Basecamp.Icons
import Basecamp.Objects

import "BasecampHomeModules.js" as M

// Basecamp's home page (the `home` role, ADR-067): what a New tab shows.
// The bar's text searches both apps and what apps share with Basecamp
// (SHELL-OBJECTS-SPEC §7): pills narrow the objects by type or app; below,
// either the feed (everything, newest first; the default) or the modules
// (saved filters, a grid that is one column on a phone). Above them, with
// nothing typed, Recent apps: the ones closed or installed lately, newest
// first, then Applications, Packages and Settings, which are apps like any
// other (basecamp-experiments#30). With a query, the Apps block instead: the
// installed and catalog apps that match, one row each, Running or with an
// Open or Install button (basecamp-experiments#32). Under a type pill, the
// same block lists the installed apps that share that type, whatever is
// typed (basecamp-experiments#36).
// In the desktop's Activity sidebar (feedOnly, basecamp-experiments#44) only
// the search, the pills and the feed show: no Recent apps, Apps block or
// modules.
// Picking a tile asks the shell to turn the current New tab into that app; a
// card's actions go to the app that published it. It reads only `shell`, the
// role-gated object the host injects.
//
// The modules (order, size, pin, notify, the custom ones) and their layout
// on the grid are kept by the shell for home (shell.homeSettings, saved with
// shell.saveHomeSettings), so a restart keeps them. The layout changes only
// in edit mode (basecamp-experiments#51): Edit home, or a long press on a
// module's header; a module then moves by dragging, Done saves and Cancel
// or Esc puts back what was there before.
Rectangle {
    id: root

    signal launchApp(string name)

    function focusSearch() { search.forceActiveFocus() }
    // The shell calls this each time it shows a New tab: a new visit.
    function clearSearch() {
        search.text = ""
        root.pill = null
        root.startVisit()
    }
    // Esc in the search (#47): clears what was typed, the type pill stays.
    // True when there was text to clear; the desktop shell asks this before
    // Esc closes the overlay or the sidebar. Basecampium's compact bar is the
    // shell's own, with its own Esc (Back).
    // With a result focused from the keyboard (#48), Esc first takes the
    // focus back to the field, the text kept.
    // In edit mode Esc cancels it first (#51).
    function escapeSearch() {
        if (root.editing) {
            root.cancelEdit()
            return true
        }
        if (root.searchInBar)
            return false
        if (root.resultFocused()) {
            root.focusSearch()
            return true
        }
        if (search.text.length === 0)
            return false
        search.text = ""
        return true
    }

    // ── keyboard (basecamp-experiments#48) ──────────────────────────────
    // Down from the search moves into the results: Recent apps (Left and
    // Right along the row), then down the Apps block's rows and the cards
    // (the feed's, or the modules' in reading order). Up from the first
    // returns to the search. Enter does what a click on it would (a card:
    // its primary action, ObjectCard.activate). Typing goes back to the
    // search. The results take real focus (screen readers follow it) and
    // draw an accent ring while they hold it; the page scrolls to keep the
    // focused one in view. The phone layout's search is the shell's bar,
    // so none of this applies there.
    function within(item, ancestor) {
        for (let it = item; it; it = it.parent)
            if (it === ancestor) return true
        return false
    }
    function focusedItem() { return root.Window.window ? root.Window.window.activeFocusItem : null }
    function resultFocused() {
        const f = root.focusedItem()
        return f !== null && root.within(f, page) && !root.within(f, search)
    }
    // The lines under Recent apps, top to bottom, each the results side by
    // side on it: an app row, a card, or a module's cards in a strip or two
    // columns (Left and Right go along those, M.navMove).
    function navGroups() {
        const out = []
        if (appsBlock.visible)
            for (let i = 0; i < appHitRepeater.count; ++i) {
                const it = appHitRepeater.itemAt(i)
                if (it) out.push([it])
            }
        if (feed.visible)
            return out.concat(feed.navCards().map(c => [c]))
        if (grid.visible) {
            const mods = []
            for (let i = 0; i < moduleRepeater.count; ++i) {
                const m = moduleRepeater.itemAt(i)
                if (m && m.visible) mods.push(m)
            }
            mods.sort((a, b) => a.y !== b.y ? a.y - b.y : a.x - b.x)
            for (const m of mods) out.push(...m.navGroups())
        }
        return out
    }
    // The same flattened: `rows` top to bottom and left to right, `lines`
    // the line each is on.
    function navLayout() {
        const rows = [], lines = []
        const groups = root.navGroups()
        for (let g = 0; g < groups.length; ++g)
            for (const it of groups[g]) { rows.push(it); lines.push(g) }
        return { rows: rows, lines: lines }
    }
    function navRows() { return root.navLayout().rows }
    // Which result `f` is in: { where: "tile" | "row", index, stop, key }
    // (key: the card's object or the app row's app, to find it again), or
    // null. `rows` is navRows().
    function locate(f, rows) {
        if (!f) return null
        if (appRow.visible)
            for (let i = 0; i < appRow.count; ++i) {
                const t = appRow.itemAtIndex(i)
                if (t && root.within(f, t)) return { where: "tile", index: i, stop: t, key: "" }
            }
        for (let i = 0; i < rows.length; ++i)
            if (root.within(f, rows[i])) {
                const r = rows[i]
                const key = r.object && r.object.id ? "object:" + r.object.id
                          : r.hit && r.hit.name ? "app:" + r.hit.name : ""
                return { where: "row", index: i, stop: r, key: key }
            }
        return null
    }
    // The result last focused from the keyboard ({ where, index, key }) and
    // its item. The feed and the Apps block are drawn again whenever their
    // results change (a pending payment moves every few seconds), which
    // drops the focused card; the focus then goes back to the same object,
    // or the same place. Only then: when the focus leaves for somewhere else
    // (the window lost it, a click in the dock or another app) while the
    // result is still there, nothing is taken back.
    property var navAt: null
    property Item navItem: null
    function restoreNav() {
        const at = root.navAt
        const f = root.focusedItem()
        if (!at || (f && root.within(f, page))) return
        // The result is still on the page: the focus left for somewhere else
        // (the window lost it, a click in the dock or another app), so it
        // stays there and the ring goes out (#48 review). A redrawn result
        // is out of the page by now (unparented, or destroyed: null).
        const old = root.navItem
        if (old && old.visible && root.within(old, page)) {
            root.navAt = null
            root.navItem = null
            return
        }
        if (at.where === "tile") {
            if (appRow.visible && appRow.count > 0) root.focusTile(Math.min(at.index, appRow.count - 1))
            else root.focusSearch()
            return
        }
        const rows = root.navRows()
        if (rows.length === 0) { root.focusSearch(); return }
        let target = rows[Math.min(at.index, rows.length - 1)]
        for (const r of rows)
            if (at.key.length > 0 && root.locate(r, [r]).key === at.key) { target = r; break }
        target.forceActiveFocus(Qt.TabFocusReason)
    }
    function noteFocus() {
        const f = root.focusedItem()
        const at = root.locate(f, root.navRows())
        if (at) {
            root.navAt = { where: at.where, index: at.index, key: at.key }
            root.navItem = at.stop
        } else if (root.navAt && (!f || !root.within(f, page))) {
            // Its result may have been drawn again: once that is done,
            // restoreNav brings the focus back to the new one.
            Qt.callLater(root.restoreNav)
            return
        } else {
            root.navAt = null
            root.navItem = null
        }
        Qt.callLater(root.revealFocus)
    }
    function focusTile(i) {
        if (appRow.count === 0) return
        appRow.currentIndex = i
        appRow.positionViewAtIndex(i, ListView.Contain)
        const t = appRow.itemAtIndex(i)
        if (t) t.forceActiveFocus(Qt.TabFocusReason)
    }
    function navKey(event) {
        const f = root.focusedItem()
        if (!f || !root.within(f, root)) return
        // Edit mode: Esc cancels it; the arrows and Enter stay out of the
        // inert cards.
        if (root.editing) {
            if (event.key === Qt.Key_Escape) {
                root.cancelEdit()
                event.accepted = true
                return
            }
            const nav = [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Return, Qt.Key_Enter]
            if (nav.indexOf(event.key) >= 0 && !root.within(f, search)) return
        }
        if (root.searchInBar) return
        const inSearch = root.within(f, search)
        if (!inSearch && root.within(f, page) && M.typesText(event.text, event.modifiers)) {
            root.focusSearch()
            search.textInput.cursorPosition = search.text.length
            search.textInput.insert(search.textInput.cursorPosition, event.text)
            event.accepted = true
            return
        }
        if (!inSearch && event.key === Qt.Key_Backspace && root.within(f, page)) {
            root.focusSearch()
            search.textInput.cursorPosition = search.text.length
            if (search.text.length > 0)
                search.textInput.remove(search.text.length - 1, search.text.length)
            event.accepted = true
            return
        }
        if (!inSearch && event.key === Qt.Key_Escape) {
            event.accepted = root.escapeSearch()
            return
        }
        const key = { [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
                      [Qt.Key_Left]: "left", [Qt.Key_Right]: "right" }[event.key]
        const isEnter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        if (!key && !isEnter) return

        const tiles = appRow.visible ? appRow.count : 0
        const nav = root.navLayout()
        const rows = nav.rows
        const from = inSearch ? { where: "search" } : root.locate(f, rows)
        if (!from) return
        const stop = from.stop
        if (isEnter) {
            // A card takes its own Enter; a tile or an app row opens.
            if (stop && typeof stop.activate === "function" && stop.activeFocus) {
                stop.activate()
                event.accepted = true
            }
            return
        }
        const to = M.navMove(from, key, tiles, rows.length, appRow.currentIndex, nav.lines)
        if (!to) return
        event.accepted = true
        if (to.where === "search") root.focusSearch()
        else if (to.where === "tile") root.focusTile(to.index)
        else rows[to.index].forceActiveFocus(Qt.TabFocusReason)
    }
    Keys.onPressed: event => root.navKey(event)

    // Keeps what has the focus in view, the search included.
    function revealFocus() {
        const f = root.focusedItem()
        if (!f || !root.within(f, page)) return
        // Back in the search: the page's top, as it was before.
        if (root.within(f, search)) {
            scroll.contentY = 0
            return
        }
        const item = f
        const p = item.mapToItem(scroll.contentItem, 0, 0)
        const pad = Theme.spacing.medium
        let y = scroll.contentY
        if (p.y + item.height + pad > y + scroll.height) y = p.y + item.height + pad - scroll.height
        if (p.y - pad < y) y = p.y - pad
        scroll.contentY = Math.max(0, Math.min(y, scroll.contentHeight - scroll.height))
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { root.noteFocus() }
    }

    // Basecampium's compact layout puts the search in its one bar
    // (docs/MOBILE-LAYOUT.md §8): this page then shows the results only.
    property bool searchInBar: false
    property string barQuery: ""
    // The desktop's Activity sidebar: the search, the pills and the feed only.
    property bool feedOnly: false
    // What is typed, and what the results are for: the same text a moment
    // after the last keystroke (basecamp-experiments#27, the flood test:
    // each search ranks the whole store, so typing fast asked for one per
    // letter). Emptied at once (Esc, a new visit); Enter applies it first.
    readonly property string typedQuery: (searchInBar ? barQuery : search.text).trim()
    property string rawQuery: ""
    readonly property string query: rawQuery.toLowerCase()
    onTypedQueryChanged: {
        if (root.typedQuery.length === 0) root.applyQuery()
        else queryTimer.restart()
    }
    function applyQuery() {
        queryTimer.stop()
        root.rawQuery = root.typedQuery
    }
    Timer {
        id: queryTimer
        interval: 100
        onTriggered: root.applyQuery()
    }
    // Phone width (Basecampium's compact layout): tighter margins and tiles.
    readonly property bool compact: width < 600
    readonly property int sideMargin: compact ? Theme.spacing.medium : Theme.spacing.xlarge * 2
    readonly property int contentWidth: Math.min(width - 2 * sideMargin, 1200)
    // Tiles the size of the Applications grid's (80), so an app looks the same in both.
    readonly property int tileSize: 80
    // Art plus a label of up to two lines ("Package Manager" at 390).
    readonly property int tileHeight: tileSize + 56
    readonly property int pitch: compact ? 108 : 124

    // Every installed app you can open, by name. Applications, Packages and
    // Settings are among them; home itself and the search ranker are not.
    readonly property var hidden: {
        const roles = shell.roles || ({})
        return [roles.home || "", roles.search || ""].filter(n => n.length > 0)
    }
    readonly property var apps: {
        const list = (shell.installedApps || []).filter(a => root.hidden.indexOf(a.name) < 0)
        list.sort((a, b) => (a.displayName || a.name).localeCompare(b.displayName || b.name))
        return list
    }
    // Recent apps: closed or installed lately, newest first (the host keeps
    // both), then whichever of Applications, Packages and Settings is not
    // already there. A fresh profile shows just those three.
    readonly property int maxRecent: 12
    readonly property var recentApps: {
        const out = []
        const add = a => {
            if (a && root.hidden.indexOf(a.name) < 0 && !out.some(o => o.name === a.name))
                out.push(a)
        }
        for (const a of (shell.recentApps || [])) add(a)
        const roles = shell.roles || ({})
        for (const role of ["launcher", "packages", "settings"])
            add((shell.installedApps || []).find(a => a.name === (roles[role] || "")))
        return out.slice(0, root.maxRecent)
    }
    readonly property var appNames: {
        const names = {}
        for (const a of (shell.installedApps || [])) names[a.name] = a.displayName || a.name
        return names
    }

    // The Apps block: what shell.findApps answers for the bar's text, best
    // first ({ name, title, icon, fullBleed, state }). Asked again when the
    // text changes and when the host says the answer would differ (an app
    // opened, closed or installed, the catalog arrived).
    property var appHits: []
    readonly property int maxAppHits: 5
    function refreshApps() {
        root.appHits = root.rawQuery.length > 0 ? (shell.findApps(root.rawQuery) || []) : []
    }
    // Under a type pill: shell.relatedApps, the installed apps that publish
    // that type, in the same row shape. Asked again when the pill changes and
    // when the host says the store or the apps changed; not with the pill's
    // results, which follow the text and miss objects it does not match.
    property var relatedHits: []
    function refreshRelated() {
        root.relatedHits = root.pill && root.pill.type ? (shell.relatedApps(root.pill.type) || []) : []
    }
    // What the Apps block lists: the related apps under a type pill, the
    // apps found for the text without a pill, nothing under an app pill.
    readonly property var shownAppHits: !root.pill ? root.appHits
                                      : root.pill.type ? root.relatedHits : []
    Connections {
        target: shell
        function onAppResultsChanged() { root.refreshApps(); root.refreshRelated() }
        function onRelatedAppsChanged() { root.refreshRelated() }
    }

    function openApp(hit) {
        if (hit.state === "available") shell.installApp(hit.name)
        else if (hit.state !== "installing") root.launchApp(hit.name)
    }
    // Enter: the first app found that is installed (never an install).
    function openFirst() {
        if (root.feedOnly) return
        if (queryTimer.running) root.applyQuery()
        const hit = root.appHits.find(a => a.state === "running" || a.state === "installed")
        if (root.query.length > 0 && hit) root.launchApp(hit.name)
    }

    // ── objects ─────────────────────────────────────────────────────────

    // { type, app } narrowing every module and the feed; null = all.
    property var pill: null
    // "feed" (the default) or "grid" (modules), as the toggle left it;
    // the sidebar's feed mode always shows the feed.
    property string chosenView: "feed"
    readonly property string view: root.feedOnly ? "feed" : root.chosenView
    // As saved (M.fromSettings), else the defaults.
    property var modules: M.fromSettings(shell.homeSettings).modules
    // The modules' places on the grid, one layout per column count it was
    // arranged at ({ "<columns>": layout }); none yet derives them from the
    // modules' old size and pin (M.layoutFor).
    property var layouts: M.fromSettings(shell.homeSettings).layouts
    onModulesChanged: root.saveSettings()
    function saveSettings() {
        if (!shell.saveHomeSettings(M.settingsOf(root.modules, root.layouts)))
            console.warn("Home: the shell did not keep home's settings")
    }
    // Saved from another view of home (the overlay, another window): taken
    // over unless this one is being arranged. The modules only when they
    // differ, since new ones rebuild every module.
    Connections {
        target: shell
        function onHomeSettingsChanged() {
            if (root.editing) return
            const s = M.fromSettings(shell.homeSettings)
            if (JSON.stringify(s.layouts) !== JSON.stringify(root.layouts)) root.layouts = s.layouts
            if (JSON.stringify(s.modules) !== JSON.stringify(root.modules)) root.modules = s.modules
        }
    }

    // ── edit mode (basecamp-experiments#51) ───────────────────────────────
    // The grid's layouts while arranging: a copy of `layouts` that each move
    // writes for the current column count. Done keeps it, Cancel drops it.
    property bool editing: false
    property var draft: ({})
    function startEdit() {
        if (root.editing || root.feedOnly) return
        root.draft = Object.assign({}, root.layouts)
        root.chosenView = "grid"
        root.editing = true
        // The button pressed goes away: Done takes the focus, so Esc and
        // Enter reach home.
        Qt.callLater(() => { if (root.editing) editDone.forceActiveFocus(Qt.OtherFocusReason) })
    }
    function finishEdit() {
        if (!root.editing) return
        grid.endDrag()
        root.layouts = root.draft
        root.editing = false
        root.saveSettings()
    }
    function cancelEdit() {
        if (!root.editing) return
        grid.endDrag()
        root.editing = false
        root.draft = ({})
    }
    // "Reset layout": the first layout for this column count, from the
    // modules' old size and pin (M.migrateLayout); kept with Done.
    function resetLayout() {
        root.setDraft(M.migrateLayout(root.modules, grid.columns))
    }
    function setDraft(layout) {
        const d = Object.assign({}, root.draft)
        d[String(layout.columns)] = layout
        root.draft = d
    }

    // One live result for whether anything matches: the bar's text, no filter.
    property var allResults: null
    property var allRows: []
    // The feed's own, narrowed by the pill: a results model holds at most 200
    // objects, so the feed under a pill must not be a slice of everything's.
    // Made when a pill is first picked; with none, the feed is allResults.
    property var pillResults: null
    property var pillRows: []
    // What the pills count: every object the bar's text matches, uncapped
    // (shell.counts), read again whenever the results change.
    property var counts: ({})
    readonly property var pillSet: ({ types: root.counts.types || [], apps: root.counts.apps || [] })
    readonly property var feedRows: M.feedRows(root.pill ? root.pillRows : root.allRows, root.pill)
    // How many the feed would show uncapped (the pill's count, or all).
    readonly property int feedTotal: {
        if (!root.pill) return root.counts.total || 0
        const list = root.pill.type ? root.pillSet.types : root.pillSet.apps
        const hit = list.find(p => (root.pill.type ? p.type === root.pill.type : p.app === root.pill.app))
        return hit ? hit.count : 0
    }

    // What this visit shows as new (id -> true), and the ids noted since the
    // last markSeen. A visit starts when the shell shows a New tab.
    property var newIds: ({})
    property var toMark: []
    property int visit: 0
    property real now: Date.now()
    // On screen: the shell hides home's view behind other tabs, which hides
    // its window. Nothing is marked seen while it is hidden.
    readonly property bool onScreen: Window.window !== null && Window.window.visibility !== Window.Hidden
    // Deferred: the shell shows the view before it starts the visit
    // (clearSearch), and marking first would make the hidden visit "seen".
    // Leaving home while arranging it (another tab, the overlay closed)
    // cancels; the edit bar says so.
    onOnScreenChanged: {
        if (root.onScreen) Qt.callLater(root.noteFeedShown)
        else root.cancelEdit()
    }
    function noteFeedShown() {
        if (root.view === "feed") root.noteShown(root.feedRows.slice(0, feed.shown))
    }

    function startVisit() {
        root.flushMarks()
        root.now = Date.now()
        root.newIds = ({})
        root.visit += 1
        if (root.view === "feed") root.noteShown(root.feedRows.slice(0, feed.shown))
    }

    // `rows` are on screen: the unseen among them are new for this visit and
    // are marked seen shortly (they keep their dot until the next visit).
    // Hidden, they are left alone, so the first look still counts them new.
    function noteShown(rows) {
        if (!root.onScreen) return
        const r = M.addUnseen(root.newIds, rows)
        if (r.added.length === 0) return
        root.newIds = r.map
        root.toMark = root.toMark.concat(r.added)
        markTimer.restart()
    }

    function raise(id, action, text) {
        if (shell.raise(id, action, text || "") === "")
            console.warn("Home: the shell refused", action, "on", id)
    }

    function pillLabel(p) {
        if (!p) return ""
        if (p.type) return ObjectCardFormat.typeLabel(p.type, true)
        return root.appNames[p.app] || p.app
    }

    // What the bar reads (§7): what it searches. The shell's bar on a phone
    // (shell.setBarPlaceholder), this page's own on a desktop.
    readonly property string barPlaceholder: !root.pill ? qsTr("Search Basecamp…")
        : root.pill.type ? qsTr("Search %1…").arg(root.pillLabel(root.pill).toLowerCase())
                         : qsTr("Search %1…").arg(root.pillLabel(root.pill))
    onBarPlaceholderChanged: shell.setBarPlaceholder(root.barPlaceholder)

    function setPill(p) {
        const same = root.pill && p && root.pill.type === p.type && root.pill.app === p.app
        root.pill = same || !p ? null : p
    }

    // The modules with the bar's text and the pill added as one, or null when
    // home would refuse it (nothing to save, a duplicate, no room).
    readonly property string customName: M.customName(root.rawQuery, root.pillLabel(root.pill))
    readonly property var withCustom: M.addModule(root.modules, root.customName, root.rawQuery, root.pill)
    function addModule() {
        if (root.withCustom) root.modules = root.withCustom
    }

    function refreshAll() {
        if (root.allResults) root.allResults.update(root.rawQuery, {})
        else root.allResults = shell.search(root.rawQuery, {})
        rebuildAll()
        refreshPill()
    }
    function rebuildAll() {
        root.allRows = root.rowsOf(root.allResults)
        root.counts = shell.counts(root.rawQuery) || ({})
        if (root.view === "feed" && !root.pill) root.noteShown(root.feedRows.slice(0, feed.shown))
    }
    function refreshPill() {
        root.refreshRelated()
        if (!root.pill) { root.pillRows = []; return }
        if (root.pillResults) root.pillResults.update(root.rawQuery, M.pillFilter(root.pill))
        else root.pillResults = shell.search(root.rawQuery, M.pillFilter(root.pill))
        rebuildPill()
    }
    function rebuildPill() {
        if (!root.pill) return
        root.pillRows = root.rowsOf(root.pillResults)
        if (root.view === "feed") root.noteShown(root.feedRows.slice(0, feed.shown))
    }
    function rowsOf(results) {
        const rows = []
        if (results)
            for (let i = 0; i < results.count; ++i) rows.push(results.get(i))
        return rows
    }

    onRawQueryChanged: { flushMarks(); refreshAll(); refreshApps() }
    onPillChanged: { flushMarks(); refreshPill() }
    onViewChanged: {
        if (root.view === "feed") root.noteShown(root.feedRows.slice(0, feed.shown))
        if (root.view !== "grid") root.cancelEdit()
    }
    Connections {
        target: root.allResults
        function onResultsChanged() { root.rebuildAll() }
    }
    Connections {
        target: root.pillResults
        function onResultsChanged() { root.rebuildPill() }
    }
    // Results are JS-owned and the GC is lazy: free them now, so they stop
    // following the store and do not count against this view's live ones.
    Component.onDestruction: {
        if (root.allResults) root.allResults.destroy()
        if (root.pillResults) root.pillResults.destroy()
    }

    Timer {
        id: markTimer
        interval: 1500
        onTriggered: root.flushMarks()
    }
    // Marks what was noted now. The host marks only ids still in this view's
    // results, so this runs before the results change under them too (new
    // text, a pill, the modules dropping theirs), or they would stay unseen
    // for good: noted, in newIds, never noted again in this visit.
    function flushMarks() {
        markTimer.stop()
        if (root.toMark.length > 0) shell.markSeen(root.toMark)
        root.toMark = []
    }
    // Relative times ("5 min") move on.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    color: Theme.palette.background

    // The search keeps focus, and Qt's own cursor blinks forever: each blink
    // redraws the whole New tab, so an idle window never stops drawing
    // (~5% CPU in software rendering, basecamp-theming#20). This cursor
    // blinks for a few seconds after the last edit, then stays solid. A
    // cursor delegate also stops TextInput's built-in blink timer.
    Component {
        id: calmCursor
        Rectangle {
            id: caret
            property bool blinking: true
            readonly property Item input: parent
            width: 1
            color: input ? input.color : Theme.palette.text
            visible: input ? input.cursorVisible : false
            onVisibleChanged: { blinking = true; calm.restart() }
            Component.onCompleted: calm.start()

            SequentialAnimation {
                running: caret.visible && caret.blinking
                loops: Animation.Infinite
                alwaysRunToEnd: true            // stop on the visible half
                PauseAnimation { duration: 600 }
                PropertyAction { target: caret; property: "opacity"; value: 0 }
                PauseAnimation { duration: 600 }
                PropertyAction { target: caret; property: "opacity"; value: 1 }
            }
            Timer { id: calm; interval: 10000; onTriggered: caret.blinking = false }
            Connections {
                target: caret.input
                function onTextChanged() { caret.blinking = true; calm.restart() }
                function onCursorPositionChanged() { caret.blinking = true; calm.restart() }
            }
        }
    }
    Component.onCompleted: {
        search.textInput.cursorDelegate = calmCursor
        shell.setBarPlaceholder(root.barPlaceholder)
        root.rawQuery = root.typedQuery
        root.refreshAll()
        root.refreshApps()
        root.startVisit()
    }

    // Pills: All, one per type, one per app; scrolls sideways. The view
    // toggle (modules / feed) stays at the end. On a desktop they sit under
    // the page's own search; on a phone, where the search is the shell's
    // bottom bar, they sit just above it, under the thumb with the query
    // (basecamp-experiments#34).
    readonly property bool hasPills: root.allRows.length > 0 || root.pill !== null
    readonly property bool pillsAtBottom: root.compact && root.searchInBar
    Component {
        id: pillsBar
        Item {
            objectName: "home.pills"
            height: Theme.minTouchTarget

            // A Flickable over a Row, not a ListView: every pill exists, so
            // each can be found by its objectName.
            Flickable {
                id: pillList
                anchors.left: parent.left
                anchors.right: viewToggle.left
                anchors.rightMargin: viewToggle.visible ? Theme.spacing.small : 0
                height: parent.height
                contentWidth: pillRow.width
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: pillRow
                    spacing: Theme.spacing.small
                    Repeater {
                        model: [{ key: "all" }]
                               .concat(root.pillSet.types.map(t => ({ key: t.type, type: t.type, count: t.count })))
                               .concat(root.pillSet.apps.length > 1
                                       ? root.pillSet.apps.map(a => ({ key: "app." + a.app, app: a.app, count: a.count }))
                                       : [])
                        delegate: LogosButton {
                            required property var modelData
                            readonly property bool selected: modelData.key === "all"
                                ? root.pill === null
                                : root.pill !== null && (root.pill.type || "") === (modelData.type || "")
                                  && (root.pill.app || "") === (modelData.app || "")
                            objectName: "home.pill." + modelData.key
                            height: Theme.minTouchTarget
                            text: modelData.key === "all" ? qsTr("All")
                                : qsTr("%1 %2").arg(root.pillLabel({ type: modelData.type || "", app: modelData.app || "" }))
                                               .arg(modelData.count)
                            variant: selected ? LogosButton.Variant.Primary : LogosButton.Variant.Secondary
                            onClicked: root.setPill(modelData.key === "all" ? null
                                                    : { type: modelData.type || "", app: modelData.app || "" })
                        }
                    }
                }
            }

            LogosIconButton {
                id: viewToggle
                objectName: "home.viewToggle"
                visible: !root.feedOnly && !root.editing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? Theme.minTouchTarget : 0
                size: Theme.minTouchTarget
                iconSource: root.view === "grid" ? LogosIcons.list : LogosIcons.grid
                Accessible.name: root.view === "grid" ? qsTr("Show the feed") : qsTr("Show the modules")
                onClicked: root.chosenView = root.view === "grid" ? "feed" : "grid"
            }
        }
    }

    // The phone's pills, docked on the page's bottom edge (the shell's
    // search bar is just below it); the page above stops at the dock, so
    // no card hides behind the pills.
    Rectangle {
        id: pillDock
        objectName: "home.pillDock"
        visible: root.hasPills && root.pillsAtBottom && !root.editing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.minTouchTarget + 2 * Theme.spacing.small
        color: Theme.palette.background

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.palette.borderHairline
        }

        Loader {
            active: pillDock.visible
            x: root.sideMargin
            width: parent.width - 2 * root.sideMargin
            height: Theme.minTouchTarget
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: pillsBar
        }
    }

    // Edit mode's bar (#51), docked on the page's bottom edge (on a phone in
    // place of the pills): what to do, Reset layout, Cancel and Done.
    Rectangle {
        id: editBar
        objectName: "home.editBar"
        visible: root.editing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: barBody.height + 2 * Theme.spacing.small
        color: Theme.palette.backgroundElevated
        z: 3

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.palette.borderHairline
        }

        Item {
            id: barBody
            x: root.sideMargin
            y: Theme.spacing.small
            width: parent.width - 2 * root.sideMargin
            // A phone puts the words above the buttons.
            height: root.compact ? editHint.implicitHeight + Theme.spacing.tiny + Theme.minTouchTarget
                                 : Math.max(Theme.minTouchTarget, editHint.implicitHeight)

            LogosText {
                id: editHint
                objectName: "home.editBar.hint"
                anchors.left: parent.left
                anchors.right: root.compact ? parent.right : editButtons.left
                anchors.rightMargin: root.compact ? 0 : Theme.spacing.medium
                y: root.compact ? 0 : (parent.height - height) / 2
                wrapMode: Text.Wrap
                text: qsTr("Drag a module to move it. Changes are kept when you press Done.")
                color: Theme.palette.textSecondary
                font.pixelSize: Theme.typography.secondaryText
            }

            Row {
                id: editButtons
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacing.small

                LogosButton {
                    objectName: "home.edit.reset"
                    height: Theme.minTouchTarget
                    text: qsTr("Reset layout")
                    onClicked: root.resetLayout()
                }
                LogosButton {
                    objectName: "home.edit.cancel"
                    height: Theme.minTouchTarget
                    text: qsTr("Cancel")
                    onClicked: root.cancelEdit()
                }
                LogosButton {
                    id: editDone
                    objectName: "home.edit.done"
                    height: Theme.minTouchTarget
                    text: qsTr("Done")
                    variant: LogosButton.Variant.Primary
                    onClicked: root.finishEdit()
                    Keys.onReturnPressed: root.finishEdit()
                    Keys.onEnterPressed: root.finishEdit()
                }
            }
        }
    }

    // A module held near the top or bottom edge scrolls the page (#51).
    Timer {
        interval: 16
        repeat: true
        running: grid.dragId.length > 0
        onTriggered: {
            const step = M.autoScrollStep(grid.pointer.y, scroll.height, 16)
            if (step === 0) return
            const y = Math.max(0, Math.min(scroll.contentY + step, scroll.contentHeight - scroll.height))
            if (y === scroll.contentY) return
            scroll.contentY = y
            grid.follow()
        }
    }

    Flickable {
        id: scroll
        objectName: "home.scroll"
        anchors.fill: parent
        anchors.bottomMargin: editBar.visible ? editBar.height : pillDock.visible ? pillDock.height : 0
        contentWidth: width
        contentHeight: page.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
        id: page
        x: root.sideMargin + (root.width - 2 * root.sideMargin - root.contentWidth) / 2
        width: root.contentWidth
        topPadding: root.compact ? Theme.spacing.medium : Theme.spacing.xlarge * 2
        spacing: root.compact ? Theme.spacing.medium : Theme.spacing.large

        LogosSearchBar {
            id: search
            objectName: "home.bar"
            visible: !root.searchInBar
            focus: true
            // As wide as the feed cards below, so its edges line up with them.
            width: parent.width
            height: Theme.components.search.height
            // The bar names what it narrows (§7).
            placeholderText: root.barPlaceholder
            // In the sidebar Ctrl+K opens the overlay instead.
            shortcutHint: root.feedOnly ? "" : "Ctrl+K"
            onSubmitted: root.openFirst()
            Keys.onReturnPressed: root.openFirst()
            Keys.onEnterPressed: root.openFirst()
            Keys.onEscapePressed: event => { event.accepted = root.escapeSearch() }
        }

        Loader {
            active: root.hasPills && !root.pillsAtBottom
            visible: active
            width: parent.width
            height: active ? Theme.minTouchTarget : 0
            sourceComponent: pillsBar
        }

        LogosText {
            objectName: "home.recentApps.title"
            visible: appRow.visible && root.query.length === 0
            width: parent.width
            text: qsTr("Recent apps")
            font.pixelSize: Theme.typography.secondaryText
            font.weight: Font.Medium
            color: Theme.palette.textSecondary
        }

        // Recent apps, in one row that scrolls sideways.
        ListView {
            id: appRow
            objectName: "newTab.grid"
            visible: !root.feedOnly && root.pill === null && root.query.length === 0
                     && root.recentApps.length > 0
            width: parent.width
            height: visible ? root.tileHeight : 0
            orientation: ListView.Horizontal
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Left and Right go through home's keys (navKey), which move the focus.
            keyNavigationEnabled: false
            model: root.recentApps
            delegate: Tile {
                required property var modelData
                required property int index
                objectName: "newTab.app." + modelData.name
                key: modelData.name
                label: modelData.displayName || modelData.name
                artwork: modelData.iconPath || ""
                fullBleed: modelData.supportsFullBleedIcon === true
                loading: (shell.loadingModules || []).indexOf(modelData.name) >= 0
                onActivated: root.launchApp(modelData.name)
                onActiveFocusChanged: if (activeFocus) {
                    appRow.currentIndex = index
                    appRow.positionViewAtIndex(index, ListView.Contain)
                }
            }
        }

        LogosText {
            visible: !root.feedOnly && root.apps.length === 0 && root.allRows.length === 0
                     && root.query.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            text: qsTr("No apps yet. Find some in Applications.")
            color: Theme.palette.textSecondary
            font.pixelSize: Theme.typography.secondaryText
        }

        // ── apps found (basecamp-experiments#32) ────────────────────────
        Column {
            id: appsBlock
            objectName: "home.apps"
            visible: !root.feedOnly && root.shownAppHits.length > 0
            // The content column's width, like the bar and the cards.
            width: parent.width

            Item {
                width: parent.width
                height: Theme.minTouchTarget

                LogosText {
                    objectName: "home.apps.title"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Apps")
                    font.pixelSize: Theme.typography.secondaryText
                    font.weight: Font.Medium
                    color: Theme.palette.textSecondary
                }

                LogosLink {
                    objectName: "home.apps.all"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // The whole header's height is the tap target, text centred.
                    width: Math.max(Theme.minTouchTarget, labelItem.implicitWidth + 2 * Theme.spacing.small)
                    height: Theme.minTouchTarget
                    leftPadding: (width - labelItem.implicitWidth) / 2
                    rightPadding: leftPadding
                    topPadding: Math.max(0, (height - labelItem.implicitHeight) / 2)
                    bottomPadding: topPadding
                    text: qsTr("All apps")
                    underline: false
                    onActivated: shell.openRole("launcher")
                }
            }

            Repeater {
                id: appHitRepeater
                model: root.shownAppHits.slice(0, root.maxAppHits)
                delegate: AppRow {
                    required property var modelData
                    width: appsBlock.width
                    hit: modelData
                }
            }
        }

        LogosText {
            objectName: "home.nothing"
            // Under a pill the Apps block lists related apps, not matches,
            // so then only the pill's own results count.
            visible: root.query.length > 0
                     && (root.pill !== null || root.appHits.length === 0 || root.feedOnly)
                     && (root.pill ? root.pillRows.length === 0 : root.allRows.length === 0)
            width: parent.width
            wrapMode: Text.Wrap
            text: qsTr("Nothing matches “%1”.").arg(root.rawQuery)
            color: Theme.palette.textSecondary
            font.pixelSize: Theme.typography.secondaryText
        }

        // ── modules (basecamp-experiments#50) ─────────────────────────────
        // A grid of cells that scrolls with the page: columns by the grid's
        // width (M.columnsFor), rows kRowHeight tall; each module covers the
        // cells of its block in the layout for that column count
        // (M.layoutFor). A width change only switches layouts, it saves none.
        // Wider than the page's column on a big screen, so four columns fit.
        //
        // Edit mode (#51): every module shows, outlined, its cards inert. A
        // press and drag on one lifts it: it follows the pointer, a ghost
        // marks the cell it lands on and the others make room as it goes
        // (M.place on the layout from before the press). Near the top or
        // bottom edge the page scrolls. On a phone only the header drags a
        // module, so the rest of it still scrolls the page.

        // Wide screens: the grid's own heading, with Edit home beside it.
        Item {
            objectName: "home.grid.heading"
            visible: grid.visible && !root.compact
            width: parent.width
            height: visible ? Theme.minTouchTarget : 0

            LogosText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Modules")
                font.pixelSize: Theme.typography.secondaryText
                font.weight: Font.Medium
                color: Theme.palette.textSecondary
            }
            LogosButton {
                objectName: "home.grid.edit.top"
                visible: !root.editing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.minTouchTarget
                text: qsTr("Edit home")
                onClicked: root.startEdit()
            }
        }

        Item {
            id: grid
            objectName: "home.grid"
            visible: root.view === "grid" && root.allRows.length > 0
            width: Math.min(root.width - 2 * root.sideMargin, 1600)
            x: (parent.width - width) / 2
            height: visible ? gridHeight : 0
            readonly property int gap: Theme.spacing.medium
            readonly property int rowHeight: M.kRowHeight
            readonly property int columns: M.columnsFor(width)
            readonly property real columnWidth: (width - (columns - 1) * gap) / columns
            readonly property real pitchX: columnWidth + gap
            readonly property real pitchY: rowHeight + gap
            // Edit mode: every module keeps its cells, the empty ones too.
            readonly property bool editing: root.editing
            readonly property var layout: M.layoutFor(root.editing ? root.draft : root.layouts,
                                                      grid.columns, root.modules)
            // The modules that find nothing: outside edit mode they give up
            // their cells, as a hidden module took no room before.
            property var hiddenIds: []
            readonly property var visibleLayout: M.withoutHidden(grid.layout, grid.hiddenIds)
            readonly property var shown: grid.editing ? grid.layout : grid.visibleLayout
            readonly property int shownCount: grid.visibleLayout.blocks.length
            readonly property real gridHeight: {
                const rows = M.rowsOf(grid.shown)
                // While a module is held, room below it for where it is.
                const held = grid.dragId.length > 0 ? grid.dragY + grid.dragH : 0
                return Math.max(rows > 0 ? rows * grid.pitchY - grid.gap : 0, held)
            }

            // The module held in edit mode: its id, its top left and size in
            // px as the pointer leaves it, where it was taken (in it), the
            // pointer in `scroll`'s coordinates, and the layout from before
            // the press that every move starts from.
            property string dragId: ""
            property real dragX: 0
            property real dragY: 0
            property real dragW: 0
            property real dragH: 0
            property point grabAt: Qt.point(0, 0)
            property point pointer: Qt.point(0, 0)
            property var dragBase: null
            property string dropKey: ""

            function beginMove(id, card, at) {
                if (!grid.editing) return
                grid.dragBase = grid.layout
                grid.grabAt = at
                grid.dragX = card.x
                grid.dragY = card.y
                grid.dragW = card.width
                grid.dragH = card.height
                grid.dropKey = ""
                grid.dragId = id
            }
            function dragTo(p) {
                grid.pointer = p
                grid.follow()
            }
            // Puts the held module under the pointer and, when that changes
            // the cell it would land on, the others where they make room.
            function follow() {
                if (grid.dragId.length === 0) return
                const g = scroll.mapToItem(grid, grid.pointer.x, grid.pointer.y)
                grid.dragX = grid.columns <= 1 ? 0
                           : Math.max(0, Math.min(grid.width - grid.dragW, g.x - grid.grabAt.x))
                // No further down than under the last module: the page stops
                // growing (and scrolling) there.
                grid.dragY = Math.max(0, Math.min(M.rowsOf(grid.dragBase) * grid.pitchY, g.y - grid.grabAt.y))
                const b = M.blockFor(grid.dragBase, grid.dragId)
                if (!b) return
                const c = M.dropCell(grid.dragX, grid.dragY, grid.pitchX, grid.pitchY, grid.columns, b.w)
                const key = c.x + "," + c.y
                if (key === grid.dropKey) return
                grid.dropKey = key
                root.setDraft(M.place(grid.dragBase, grid.dragId, c.x, c.y))
            }
            // The module lands where its ghost is: the draft already has it.
            function endDrag() {
                grid.dragId = ""
                grid.dragBase = null
                grid.dropKey = ""
            }

            function noteHidden() {
                const ids = []
                for (let i = 0; i < moduleRepeater.count; ++i) {
                    const it = moduleRepeater.itemAt(i)
                    if (it && !it.hasContent) ids.push(it.module.id)
                }
                if (ids.join("\n") !== grid.hiddenIds.join("\n")) grid.hiddenIds = ids
            }

            // Moves are animated so a reflow reads, but not on first show
            // and not while the window is being resized.
            property bool animate: false
            function still() { grid.animate = false; animateTimer.restart() }
            onVisibleChanged: grid.still()
            onWidthChanged: grid.still()
            Timer {
                id: animateTimer
                interval: 300
                onTriggered: grid.animate = grid.visible
            }

            // Where the held module lands.
            Rectangle {
                objectName: "home.grid.ghost"
                readonly property var block: grid.dragId.length > 0 ? M.blockFor(grid.layout, grid.dragId) : null
                visible: block !== null
                x: block ? block.x * grid.pitchX : 0
                y: block ? block.y * grid.pitchY : 0
                width: block ? block.w * grid.columnWidth + (block.w - 1) * grid.gap : 0
                height: block ? block.h * grid.rowHeight + (block.h - 1) * grid.gap : 0
                radius: Theme.spacing.radiusXlarge
                color: Theme.palette.backgroundSecondary
                border.width: 2
                border.color: Theme.palette.accentOrange
                opacity: 0.6
            }

            Repeater {
                id: moduleRepeater
                model: root.modules
                delegate: BasecampHomeModule {
                    id: cardItem
                    required property var modelData
                    readonly property var block: M.blockFor(grid.shown, modelData.id)
                    readonly property bool held: grid.dragId === modelData.id
                    module: modelData
                    editing: grid.editing
                    z: held ? 2 : 1
                    x: held ? grid.dragX : block ? block.x * grid.pitchX : 0
                    y: held ? grid.dragY : block ? block.y * grid.pitchY : 0
                    width: block ? block.w * grid.columnWidth + (block.w - 1) * grid.gap : grid.columnWidth
                    height: block ? block.h * grid.rowHeight + (block.h - 1) * grid.gap : 0
                    Behavior on x { enabled: grid.animate && !cardItem.held; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: grid.animate && !cardItem.held; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on width { enabled: grid.animate && !cardItem.held; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height { enabled: grid.animate && !cardItem.held; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    barQuery: root.rawQuery
                    pill: root.pill
                    // Searching only while the modules show (#27).
                    live: root.view === "grid"
                    onReleasing: root.flushMarks()
                    now: root.now
                    newIds: root.newIds
                    visit: root.visit
                    onHasContentChanged: Qt.callLater(grid.noteHidden)
                    onRowsShown: rows => { if (root.view === "grid") root.noteShown(rows) }
                    onRaiseRequested: (id, action, text) => root.raise(id, action, text)
                    onChangeRequested: change => root.modules = M.updateModule(root.modules, modelData.id, change)
                    onRemoveRequested: root.modules = M.removeModule(root.modules, modelData.id)
                    onEditRequested: root.startEdit()

                    EditFrame {
                        anchors.fill: parent
                        card: cardItem
                    }
                }
                onItemAdded: Qt.callLater(grid.noteHidden)
                onItemRemoved: Qt.callLater(grid.noteHidden)
            }
        }

        LogosButton {
            objectName: "home.grid.edit"
            visible: grid.visible && !root.editing
            anchors.horizontalCenter: parent.horizontalCenter
            height: Theme.minTouchTarget
            text: qsTr("Edit home")
            onClicked: root.startEdit()
        }

        LogosText {
            objectName: "home.grid.empty"
            visible: grid.visible && grid.shownCount === 0 && !root.editing
            width: parent.width
            wrapMode: Text.Wrap
            text: qsTr("None of your modules has anything here. The feed shows everything.")
            color: Theme.palette.textSecondary
            font.pixelSize: Theme.typography.secondaryText
        }

        LogosButton {
            objectName: "home.addModule"
            visible: root.view === "grid" && root.allRows.length > 0 && root.withCustom !== null && !root.editing
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Add “%1” as a module").arg(root.customName)
            width: Math.min(implicitWidth, parent.width)
            onClicked: root.addModule()
        }

        // ── feed ────────────────────────────────────────────────────────
        BasecampHomeFeed {
            id: feed
            visible: root.view === "feed" && root.allRows.length > 0
            width: parent.width
            rows: visible ? root.feedRows : []
            total: root.feedTotal
            now: root.now
            newIds: root.newIds
            query: root.rawQuery
            onRaiseRequested: (id, action, text) => root.raise(id, action, text)
            onShownChanged: root.noteShown(root.feedRows.slice(0, feed.shown))
        }

        // Nothing shared yet: say what will appear here.
        LogosText {
            objectName: "home.objectsEmpty"
            visible: root.allRows.length === 0 && root.query.length === 0 && root.apps.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Messages, payments, communities and news from your apps show up here once they share them.")
            color: Theme.palette.textTertiary
            font.pixelSize: Theme.typography.secondaryText
        }

        // The page's foot: a subtle divider and the credit, centred.
        Column {
            objectName: "newTab.footer"
            visible: !root.feedOnly
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: Theme.spacing.xlarge
            bottomPadding: Theme.spacing.xlarge * 1.5
            spacing: Theme.spacing.large

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(root.width - 2 * root.sideMargin, 480)
                height: 1
                color: Theme.palette.borderHairline
            }

            LogosText {
                objectName: "newTab.credit"
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Shell package made by Alisher")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textTertiary
            }
        }

    }
    }

    // A module's edit mode layer (#51): its outline, the drag handle drawn
    // where its menu was, and what takes the press to move it.
    component EditFrame: Item {
        id: frame

        property Item card: null
        readonly property string modId: frame.card ? frame.card.module.id : ""
        readonly property string modName: frame.card ? frame.card.module.name : ""
        readonly property bool held: frame.card !== null && frame.card.held
        // The header's height, as BasecampHomeModule lays it out.
        readonly property real headerBottom: Theme.spacing.medium + Theme.minTouchTarget

        visible: grid.editing
        z: 10

        Rectangle {
            anchors.fill: parent
            radius: Theme.spacing.radiusXlarge
            color: "transparent"
            border.width: frame.held ? 2 : 1
            border.color: frame.held ? Theme.palette.accentOrange : Theme.palette.borderStrong
        }

        MouseArea {
            id: mover
            objectName: "home.module." + frame.modName + ".move"
            anchors.fill: parent
            enabled: grid.editing
            cursorShape: frame.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property bool moving: false
            // A phone drags by the header only: the rest still scrolls the page.
            onPressed: mouse => {
                mover.moving = !root.compact || mouse.y < frame.headerBottom
                mover.preventStealing = mover.moving
                if (mover.moving) grid.beginMove(frame.modId, frame.card, Qt.point(mouse.x, mouse.y))
            }
            onPositionChanged: mouse => {
                if (mover.moving) grid.dragTo(mover.mapToItem(scroll, mouse.x, mouse.y))
            }
            onReleased: mover.stop()
            onCanceled: mover.stop()
            function stop() {
                if (mover.moving) grid.endDrag()
                mover.moving = false
            }
        }

        // The drag handle: six dots in the header's right corner.
        Item {
            objectName: "home.module." + frame.modName + ".handle"
            x: frame.width - Theme.spacing.medium - width
            y: Theme.spacing.medium
            width: Theme.minTouchTarget
            height: Theme.minTouchTarget
            Accessible.role: Accessible.Grip
            Accessible.name: qsTr("Move %1").arg(frame.modName)

            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: 4
                Repeater {
                    model: 6
                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: frame.held ? Theme.palette.accentOrange : Theme.palette.textSecondary
                    }
                }
            }
        }
    }

    // One app in the Apps block: icon (letters when there is no local one),
    // name, and on the right what it is: Running, or Open, or Install. The
    // whole row does what the right side says; Running switches to it.
    component AppRow: AbstractButton {
        id: appRowItem

        property var hit: ({})
        readonly property string appState: hit.state || ""

        objectName: "home.app." + (hit.name || "")
        height: 56
        hoverEnabled: true
        // Focus from the keyboard only: a click leaves it in the search.
        focusPolicy: Qt.TabFocus
        Accessible.name: hit.title || hit.name || ""
        Accessible.description: stateLabel.visible ? stateLabel.text : actionButton.text
        onClicked: root.openApp(hit)
        // Enter (#48): what a click does.
        function activate() { root.openApp(appRowItem.hit) }

        background: Rectangle {
            radius: Theme.spacing.radiusMedium
            color: appRowItem.pressed ? Theme.palette.backgroundTertiary
                 : appRowItem.hovered || appRowItem.activeFocus ? Theme.palette.backgroundSecondary
                 : "transparent"
            // The keyboard's focus ring (#48), drawn inside: nothing moves.
            border.width: appRowItem.activeFocus ? 2 : 0
            border.color: Theme.palette.accentOrange
        }

        BasecampAppTile {
            id: appIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.tiny
            anchors.verticalCenter: parent.verticalCenter
            size: 40
            label: appRowItem.hit.title || appRowItem.hit.name || ""
            source: appRowItem.hit.icon || ""
            fullBleed: appRowItem.hit.fullBleed === true
        }

        LogosText {
            anchors.left: appIcon.right
            anchors.leftMargin: Theme.spacing.medium
            anchors.right: rowEnd.left
            anchors.rightMargin: Theme.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            // The name escaped, what the bar's text matches marked
            // (basecamp-experiments#46).
            textFormat: Text.StyledText
            text: ObjectCardFormat.mark(appRowItem.hit.title || appRowItem.hit.name || "", root.rawQuery,
                                        Theme.palette.accentOrange)
            color: Theme.palette.text
        }

        Item {
            id: rowEnd
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.tiny
            anchors.verticalCenter: parent.verticalCenter
            width: stateLabel.visible ? stateLabel.implicitWidth : actionButton.width
            height: Theme.minTouchTarget

            LogosText {
                id: stateLabel
                objectName: "home.app.state." + (appRowItem.hit.name || "")
                visible: appRowItem.appState === "running" || appRowItem.appState === "installing"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: appRowItem.appState === "running" ? qsTr("Running") : qsTr("Installing…")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosButton {
                id: actionButton
                objectName: "home.app.action." + (appRowItem.hit.name || "")
                visible: !stateLabel.visible
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.minTouchTarget
                width: Math.max(implicitWidth, 88)
                text: appRowItem.appState === "available" ? qsTr("Install") : qsTr("Open")
                variant: appRowItem.appState === "available" ? LogosButton.Variant.Primary
                                                           : LogosButton.Variant.Secondary
                Accessible.name: qsTr("%1 %2").arg(text).arg(appRowItem.hit.title || appRowItem.hit.name || "")
                onClicked: root.openApp(appRowItem.hit)
            }
        }
    }

    component Tile: AbstractButton {
        id: tile

        property string key
        property string label
        property string artwork: ""
        property bool fullBleed: false
        property bool loading: false

        signal activated()

        width: root.pitch
        height: root.tileHeight
        hoverEnabled: true
        // Focus from the keyboard only: a click leaves it in the search.
        focusPolicy: Qt.TabFocus
        Accessible.name: tile.label
        onClicked: tile.activated()
        // Enter (#48): what a click does.
        function activate() { tile.activated() }
        // Hovered or focused from the keyboard: lifted the same way.
        readonly property bool lit: tile.hovered || tile.activeFocus

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.spacing.radiusLarge
            color: tile.pressed ? Theme.palette.backgroundTertiary : Theme.palette.backgroundSecondary
            opacity: tile.lit ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            // The keyboard's focus ring (#48), on the plate's edge.
            border.width: tile.activeFocus ? 2 : 0
            border.color: Theme.palette.accentOrange
        }

        Item {
            id: art
            width: root.tileSize
            height: root.tileSize
            anchors.horizontalCenter: parent.horizontalCenter
            y: tile.lit ? 8 : 12
            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            LogosGlow {
                anchors.fill: parent
                radius: artTile.radius
                active: tile.lit
            }

            // The app's icon, or its letters when it has none.
            BasecampAppTile {
                id: artTile
                anchors.centerIn: parent
                visible: !tile.loading
                size: root.tileSize
                label: tile.label
                source: tile.artwork
                fullBleed: tile.fullBleed
            }

            BusyIndicator {
                anchors.centerIn: parent
                width: 28
                height: 28
                running: tile.loading
                visible: tile.loading
            }
        }

        LogosText {
            anchors.top: art.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.1
            text: tile.label
            font.pixelSize: Theme.typography.secondaryText
            color: tile.lit ? Theme.palette.text : Theme.palette.textSecondary
        }
    }
}
