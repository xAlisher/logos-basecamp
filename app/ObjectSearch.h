#pragma once

#include <QHash>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

class ObjectResults;
class ObjectStore;
class QTimer;

// The search protocol between views, the `search` role and the store
// (SHELL-OBJECTS-SPEC §2, §5; ADR-072).
//
//   view ──search(query, filter)──▶ ObjectSearch ──searchRequested──▶ holder
//   view ◀──ObjectResults (live)─── ObjectSearch ◀──answer(ids)────── holder
//
// * A VIEW (the `home` or `launcher` holder, or the shell itself) asks with
//   search() and gets an ObjectResults that refills on every answer.
// * The `search` HOLDER is asked with searchRequested, reads the objects the
//   filter allows with objects(), and answers ranked ids with answer(). Unknown
//   ids, ids the filter does not allow and duplicates are dropped; at most
//   kMaxAnswer are kept. Only the open request of a results model is
//   answerable: an answer to a superseded or already-answered request is stale
//   and ignored.
// * With no holder the host ranks at once (ObjectRanker); a holder that does not
//   answer within kAnswerTimeoutMs is ranked for, too, and that is logged.
// * A store change asks every live results model again, debounced.
//
// Who may do what is decided here (each call names its app), so the rules are
// unit-tested without the rest of the host; ShellApi re-checks the role on every
// call anyway, as for its other members.
//
// QtCore only, like ObjectStore.
class ObjectSearch : public QObject {
    Q_OBJECT
public:
    using HolderFn = std::function<QString(const QString& role)>;

    static constexpr int kMaxAnswer = 200;
    static constexpr int kAnswerTimeoutMs = 500;
    static constexpr int kRefreshDebounceMs = 200;
    // Live results models per view app. A view should keep one and call
    // update(); past this the oldest stops following the store.
    static constexpr int kMaxLivePerView = 8;

    static const QString& searchRole();      // "search"
    static const QString& fallbackRanker();  // "fallback"
    // The shell's own views (its switcher, tests through the backend).
    static const QString& shellView();       // "main_ui"

    ObjectSearch(ObjectStore* store, HolderFn holderOf, QObject* parent = nullptr);
    ~ObjectSearch() override;

    void setClock(std::function<qint64()> clock) { m_now = std::move(clock); }
    void setTimings(int answerTimeoutMs, int refreshDebounceMs);

    // The current `search` holder, "" for none.
    QString holder() const;
    // `home` or `launcher` holder, or the shell.
    bool isView(const QString& app) const;

    // ── Views ───────────────────────────────────────────────────────────
    // A live results model for `viewApp`, already asked for (and, with no
    // holder, already filled). Unparented: the caller owns it. nullptr when
    // `viewApp` is not a view.
    ObjectResults* search(const QString& viewApp, const QString& query,
                          const QVariantMap& filter = QVariantMap());
    // Whether `id` is in one of `viewApp`'s live results: the only objects a
    // view may act on or mark seen.
    bool inResultsOf(const QString& viewApp, const QString& id) const;
    // Marks the ids in `viewApp`'s results seen; returns those it marked.
    QStringList markSeen(const QString& viewApp, const QStringList& ids);

    // ── The search role ─────────────────────────────────────────────────
    // The envelopes `filter` allows, newest first; empty unless `app` holds `search`.
    QVariantList objects(const QString& app, const QVariantMap& filter) const;
    // false (and nothing changed) for a non-holder, or an unknown, superseded
    // or already answered request.
    bool answer(const QString& app, const QString& requestId, const QVariantList& ids);

    // ── Host ────────────────────────────────────────────────────────────
    // The host ranker, synchronously, for `filter` (tests and the backend hook).
    QStringList rankWithFallback(const QString& query, const QVariantMap& filter) const;
    // Who filled the most recent results: a holder's name or "fallback".
    QString lastRanker() const { return m_lastRanker; }
    // Roles changed hands: views that lost theirs stop, the rest ask again
    // (the holder may be someone else now).
    void rolesChanged();
    // Ask again for every live results model (the holder just started).
    void refreshAll();
    // Only the spec's keys, as string lists, plus unseenOnly.
    static QVariantMap sanitizeFilter(const QVariantMap& filter);

signals:
    // To the holder named, and no one else.
    void searchRequested(const QString& holder, const QString& requestId,
                         const QString& query, const QVariantMap& filter);
    // Forwarded from the store for the holder: something `app` published changed.
    void objectsChanged(const QString& app);
    void lastRankerChanged();

private:
    friend class ObjectResults;
    struct Open {
        QPointer<ObjectResults> results;
        QString holder;
    };

    // Ask (again) for `results`' current query and filter.
    void request(ObjectResults* results);
    void forget(ObjectResults* results);
    void fillWith(ObjectResults* results, const QStringList& ids, const QString& ranker);
    void fallback(ObjectResults* results);
    void setLastRanker(const QString& ranker);
    qint64 now() const;

    ObjectStore* m_store;
    HolderFn m_holderOf;
    std::function<qint64()> m_now;
    QList<QPointer<ObjectResults>> m_live;
    QHash<QString, Open> m_open;   // requestId -> the results it answers
    quint64 m_nextRequest = 0;
    int m_answerTimeoutMs = kAnswerTimeoutMs;
    QTimer* m_debounce = nullptr;
    QString m_lastRanker;
};
