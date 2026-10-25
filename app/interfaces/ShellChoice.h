#pragma once

#include <QString>

// Which shell Basecamp starts with, shared by the host (app/window.cpp) and
// the shells' Settings backend (src/ShellPrefs). Basecampium is the default
// shell, shown to people as "Basecamp"; the shell built into the host is kept
// as "Basecamp Legacy".
//
// [BasecampShell] shell= holds the choice:
//   missing            → the default shell (a fresh profile)
//   "legacy"           → Basecamp Legacy (older profiles wrote "" or "default")
//   anything else      → that shell package
namespace ShellChoice {

inline QString defaultShell() { return QStringLiteral("basecampium"); }
inline QString legacyValue() { return QStringLiteral("legacy"); }

inline bool isLegacy(const QString& id)
{
    return id.isEmpty() || id == QLatin1String("legacy") || id == QLatin1String("default");
}

// The shell to start: "" = Basecamp Legacy (the host's built-in shell).
//   env              BASECAMP_SHELL, wins when set
//   hasSaved/saved   the Settings choice, if any
//   defaultAvailable the default shell is installed or bundled
inline QString startShell(const QString& env, bool hasSaved, const QString& saved, bool defaultAvailable)
{
    if (!env.isEmpty())
        return isLegacy(env) ? QString() : env;
    if (hasSaved)
        return isLegacy(saved) ? QString() : saved;
    return defaultAvailable ? defaultShell() : QString();
}

// What Settings and messages call a shell.
inline QString displayName(const QString& id, const QString& fallback = QString())
{
    if (isLegacy(id))
        return QStringLiteral("Basecamp Legacy");
    if (id == defaultShell())
        return QStringLiteral("Basecamp");
    return fallback.isEmpty() ? id : fallback;
}

} // namespace ShellChoice
