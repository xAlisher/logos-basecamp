#include "KeychainBroker.h"

#include "Keychain.h"

#include <QDateTime>
#include <QDebug>
#include <QTimer>
#include <QUuid>

#include <algorithm>

namespace {

const QStringList& kinds()
{
    static const QStringList k = { QStringLiteral("message"), QStringLiteral("transaction"),
                                   QStringLiteral("login") };
    return k;
}

bool oneLine(const QString& s)
{
    for (const QChar c : s)
        if (c.category() == QChar::Other_Control || c == QChar::LineSeparator
            || c == QChar::ParagraphSeparator)
            return false;
    return true;
}

QVariantMap error(const char* code) { return { { QStringLiteral("error"), QLatin1String(code) } }; }

} // namespace

QString KeychainBroker::stateName(State s)
{
    switch (s) {
    case State::Pending:   return QStringLiteral("pending");
    case State::KeyChosen: return QStringLiteral("keyChosen");
    case State::Signing:   return QStringLiteral("signing");
    case State::Done:      return QStringLiteral("done");
    case State::Rejected:  return QStringLiteral("rejected");
    case State::Cancelled: return QStringLiteral("cancelled");
    case State::TimedOut:  return QStringLiteral("timedOut");
    case State::Failed:    return QStringLiteral("failed");
    }
    return QString();
}

KeychainBroker::KeychainBroker(Keychain* keys, QObject* parent)
    : QObject(parent)
    , m_keys(keys)
{
    m_timer = new QTimer(this);
    m_timer->setInterval(1000);
    connect(m_timer, &QTimer::timeout, this, &KeychainBroker::sweep);
}

qint64 KeychainBroker::now() const
{
    return m_now ? m_now() : QDateTime::currentMSecsSinceEpoch();
}

void KeychainBroker::armTimer()
{
    if (m_requests.isEmpty()) m_timer->stop();
    else if (!m_timer->isActive()) m_timer->start();
}

QString KeychainBroker::findOpen(const QString& requester) const
{
    for (auto it = m_requests.cbegin(); it != m_requests.cend(); ++it)
        if (it->requester == requester) return it.key();
    return QString();
}

QVariantMap KeychainBroker::requestSignature(const QString& requester, const QVariantMap& params)
{
    if (requester.isEmpty()) return error("bad_request");

    const QVariant payloadV = params.value(QStringLiteral("payload"));
    const QString kind = params.value(QStringLiteral("kind")).toString();
    const QString description = params.value(QStringLiteral("description")).toString().trimmed();
    const QString algorithm = params.value(QStringLiteral("algorithm"), QStringLiteral("ed25519")).toString();
    const QString purpose = params.value(QStringLiteral("purpose"), kind).toString();
    if (payloadV.typeId() != QMetaType::QString || !kinds().contains(kind)
        || params.value(QStringLiteral("description")).typeId() != QMetaType::QString
        || description.isEmpty() || description.size() > kMaxDescription || !oneLine(description)
        || !Keychain::purposeNames().contains(purpose))
        return error("bad_request");
    // Only what the shell can check: a signature it cannot verify must never
    // be passed on, so it is never asked for.
    if (algorithm != QStringLiteral("ed25519")) return error("bad_request");

    const auto decoded = QByteArray::fromBase64Encoding(payloadV.toString().toLatin1(),
                                                        QByteArray::AbortOnBase64DecodingErrors);
    if (!decoded || decoded.decoded.isEmpty() || decoded.decoded.size() > kMaxPayloadBytes)
        return error("bad_request");

    if (!findOpen(requester).isEmpty()) return error("busy");
    if (m_hasKeychain && !m_hasKeychain()) return error("unavailable");

    Request r;
    r.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    r.requester = requester;
    r.requesterName = m_nameFor ? m_nameFor(requester) : QString();
    if (r.requesterName.isEmpty()) r.requesterName = requester;
    r.kind = kind;
    r.description = description;
    r.algorithm = algorithm;
    r.purpose = purpose;
    r.payload = *decoded;
    r.created = now();
    m_requests.insert(r.id, r);
    armTimer();

    qInfo().noquote() << "Keychain: request" << r.id << "from" << requester << kind;
    emit requestOpened(r.id);
    emit requestsChanged();
    return { { QStringLiteral("requestId"), r.id } };
}

bool KeychainBroker::cancelByRequester(const QString& requester, const QString& requestId)
{
    const QString id = requestId.isEmpty() ? findOpen(requester) : requestId;
    const auto it = m_requests.constFind(id);
    if (id.isEmpty() || it == m_requests.cend() || it->requester != requester) return false;
    end(id, State::Cancelled, QStringLiteral("requester_cancelled"));
    return true;
}

QString KeychainBroker::stateFor(const QString& requester, const QString& requestId) const
{
    const auto it = m_requests.constFind(requestId);
    if (it == m_requests.cend() || it->requester != requester) return QString();
    return stateName(it->state);
}

QStringList KeychainBroker::openRequests() const
{
    // Oldest first: the one the user was shown first.
    QList<const Request*> list;
    for (const Request& r : m_requests) list.append(&r);
    std::sort(list.begin(), list.end(), [](const Request* a, const Request* b) {
        return a->created != b->created ? a->created < b->created : a->id < b->id;
    });
    QStringList ids;
    for (const Request* r : list) ids.append(r->id);
    return ids;
}

bool KeychainBroker::matches(const Request& r, const QString& ownerApp, const QString& keyId) const
{
    const Keychain::Key* k = m_keys ? m_keys->find(ownerApp, keyId) : nullptr;
    if (!k || k->algorithm != r.algorithm) return false;
    // A key that names no purposes signs anything; one that does, only those.
    return k->purposes.isEmpty() || k->purposes.contains(r.purpose);
}

QVariantMap KeychainBroker::requestForKeychain(const QString& requestId) const
{
    const auto it = m_requests.constFind(requestId);
    if (it == m_requests.cend()) return {};
    QVariantList keys;
    if (m_keys) {
        for (const QVariant& v : m_keys->allKeys()) {
            const QVariantMap k = v.toMap();
            if (matches(*it, k.value(QStringLiteral("ownerApp")).toString(),
                        k.value(QStringLiteral("keyId")).toString()))
                keys.append(k);
        }
    }
    QVariantMap last;
    const auto lastIt = m_lastKey.constFind(it->requester);
    if (lastIt != m_lastKey.cend() && matches(*it, lastIt->first, lastIt->second))
        last = { { QStringLiteral("ownerApp"), lastIt->first }, { QStringLiteral("keyId"), lastIt->second } };
    QVariantMap r{
        { QStringLiteral("requestId"), it->id },
        { QStringLiteral("state"), stateName(it->state) },
        { QStringLiteral("requesterApp"), it->requester },
        { QStringLiteral("requesterName"), it->requesterName },
        { QStringLiteral("description"), it->description },
        { QStringLiteral("kind"), it->kind },
        { QStringLiteral("algorithm"), it->algorithm },
        { QStringLiteral("purpose"), it->purpose },
        { QStringLiteral("keys"), keys },
        { QStringLiteral("lastKey"), last },
    };
    // Once chosen: whose app is signing, for "Waiting for …".
    if (!it->ownerApp.isEmpty()) {
        const Keychain::Key* k = m_keys ? m_keys->find(it->ownerApp, it->keyId) : nullptr;
        r.insert(QStringLiteral("signerApp"), it->ownerApp);
        r.insert(QStringLiteral("signerName"), k ? k->ownerName : it->ownerApp);
        r.insert(QStringLiteral("chosenKeyId"), it->keyId);
    }
    return r;
}

bool KeychainBroker::chooseKey(const QString& requestId, const QString& ownerApp, const QString& keyId)
{
    auto it = m_requests.find(requestId);
    if (it == m_requests.end() || it->state != State::Pending || !matches(*it, ownerApp, keyId))
        return false;
    it->state = State::KeyChosen;
    it->ownerApp = ownerApp;
    it->keyId = keyId;
    qInfo().noquote() << "Keychain: request" << requestId << "key" << keyId << "of" << ownerApp;
    const QVariantMap envelope{
        { QStringLiteral("requestId"), it->id },
        { QStringLiteral("keyId"), keyId },
        { QStringLiteral("payload"), QString::fromLatin1(it->payload.toBase64()) },
        { QStringLiteral("kind"), it->kind },
        { QStringLiteral("requesterName"), it->requesterName },
        { QStringLiteral("description"), it->description },
    };
    emit requestsChanged();
    emit signerRequested(ownerApp, envelope);
    return true;
}

bool KeychainBroker::cancelByUser(const QString& requestId)
{
    if (!m_requests.contains(requestId)) return false;
    end(requestId, State::Cancelled, QStringLiteral("user_cancelled"));
    return true;
}

int KeychainBroker::keychainClosed()
{
    int n = 0;
    const QStringList ids = m_requests.keys();
    for (const QString& id : ids) {
        const auto it = m_requests.constFind(id);
        if (it == m_requests.cend() || it->state != State::Pending) continue;
        end(id, State::Cancelled, QStringLiteral("keychain_closed"));
        ++n;
    }
    return n;
}

void KeychainBroker::signerReached(const QString& requestId)
{
    auto it = m_requests.find(requestId);
    if (it == m_requests.end() || it->state != State::KeyChosen) return;
    it->state = State::Signing;
    emit requestsChanged();
}

void KeychainBroker::signerUnreachable(const QString& requestId)
{
    const auto it = m_requests.constFind(requestId);
    if (it == m_requests.cend()) return;
    if (it->state != State::KeyChosen && it->state != State::Signing) return;
    end(requestId, State::Failed, QStringLiteral("signer_unavailable"));
}

QString KeychainBroker::completeSignature(const QString& signer, const QString& requestId,
                                          const QString& signatureBase64)
{
    const auto it = m_requests.constFind(requestId);
    if (it == m_requests.cend() || it->ownerApp.isEmpty() || it->ownerApp != signer
        || (it->state != State::KeyChosen && it->state != State::Signing)) {
        qWarning().noquote() << "Keychain:" << signer << "answered a request it does not hold";
        return QString();
    }

    // Read the key again: the user may have removed it while the signer asked.
    const Keychain::Key* key = m_keys ? m_keys->find(it->ownerApp, it->keyId) : nullptr;
    if (!key) {
        end(requestId, State::Failed, QStringLiteral("key_removed"));
        return stateName(State::Failed);
    }
    const auto sig = QByteArray::fromBase64Encoding(signatureBase64.toLatin1(),
                                                    QByteArray::AbortOnBase64DecodingErrors);
    if (!sig || !m_verify || !m_verify(key->algorithm, key->publicKey, it->payload, *sig)) {
        qWarning().noquote() << "Keychain: request" << requestId << "signature from" << signer
                             << "does not verify, not passed on";
        end(requestId, State::Failed, QStringLiteral("bad_signature"));
        return stateName(State::Failed);
    }
    m_lastKey.insert(it->requester, { it->ownerApp, it->keyId });
    end(requestId, State::Done, QString(), QString(), *sig);
    return stateName(State::Done);
}

bool KeychainBroker::rejectSignature(const QString& signer, const QString& requestId, const QString& reason)
{
    const auto it = m_requests.constFind(requestId);
    if (it == m_requests.cend() || it->ownerApp.isEmpty() || it->ownerApp != signer
        || (it->state != State::KeyChosen && it->state != State::Signing))
        return false;
    QString clean = reason.trimmed();
    if (clean.size() > kMaxReason || !oneLine(clean)) clean.clear();
    end(requestId, State::Rejected, QStringLiteral("rejected"), clean);
    return true;
}

void KeychainBroker::appClosed(const QString& app)
{
    if (app.isEmpty()) return;
    const QStringList ids = m_requests.keys();
    for (const QString& id : ids) {
        const auto it = m_requests.constFind(id);
        if (it == m_requests.cend()) continue;
        if (it->requester == app)
            end(id, State::Cancelled, QStringLiteral("requester_closed"));
        else if (it->ownerApp == app && it->state == State::Signing)
            end(id, State::Failed, QStringLiteral("signer_closed"));
    }
}

QStringList KeychainBroker::appsInvolved() const
{
    QStringList apps;
    for (const Request& r : m_requests) {
        if (!apps.contains(r.requester)) apps.append(r.requester);
        if (r.state == State::Signing && !apps.contains(r.ownerApp)) apps.append(r.ownerApp);
    }
    return apps;
}

void KeychainBroker::sweep()
{
    const qint64 t = now();
    const QStringList ids = m_requests.keys();
    for (const QString& id : ids) {
        const auto it = m_requests.constFind(id);
        if (it != m_requests.cend() && t - it->created >= kTimeoutMs)
            end(id, State::TimedOut, QStringLiteral("timeout"));
    }
    armTimer();
}

void KeychainBroker::end(const QString& id, State state, const QString& err,
                         const QString& reason, const QByteArray& signature)
{
    auto it = m_requests.find(id);
    if (it == m_requests.end()) return;
    Request r = it.value();
    // Out of the table before anyone hears of it: every ending fires once,
    // and the payload goes with the entry.
    m_requests.erase(it);
    armTimer();

    const QString status = stateName(state);
    if (err.isEmpty())
        qInfo().noquote() << "Keychain: request" << id << status;
    else
        qInfo().noquote() << "Keychain: request" << id << status << err;

    const Keychain::Key* key = (m_keys && !r.ownerApp.isEmpty()) ? m_keys->find(r.ownerApp, r.keyId) : nullptr;

    QVariantMap result{ { QStringLiteral("requestId"), id }, { QStringLiteral("status"), status } };
    if (!err.isEmpty()) result.insert(QStringLiteral("error"), err);
    // The chosen key and its signature, on done only. Nothing about any other
    // key, and nothing of the user's (label, note).
    if (state == State::Done && key) {
        result.insert(QStringLiteral("signature"), QString::fromLatin1(signature.toBase64()));
        result.insert(QStringLiteral("publicKey"), QString::fromLatin1(key->publicKey.toBase64()));
        result.insert(QStringLiteral("keyId"), r.keyId);
        result.insert(QStringLiteral("signerApp"), r.ownerApp);
    }

    QVariantMap summary{ { QStringLiteral("requestId"), id }, { QStringLiteral("status"), status } };
    if (!err.isEmpty()) summary.insert(QStringLiteral("error"), err);
    if (!reason.isEmpty()) summary.insert(QStringLiteral("reason"), reason);
    if (!r.ownerApp.isEmpty()) {
        summary.insert(QStringLiteral("signerApp"), r.ownerApp);
        summary.insert(QStringLiteral("signerName"), key ? key->ownerName : r.ownerApp);
        if (key) summary.insert(QStringLiteral("keyName"), key->name);
    }

    r.payload.fill('\0');
    r.payload.clear();

    // The signer heard of it (keyChosen or later) and this is not its own
    // answer: tell it, so it can take its sign screen down.
    const bool signerAnswered = state == State::Done || state == State::Rejected
                             || err == QStringLiteral("bad_signature");
    if (!r.ownerApp.isEmpty() && !signerAnswered)
        emit requestEnded(r.ownerApp, id, status);

    emit requestsChanged();
    emit signatureResult(r.requester, result);
    emit requestFinished(r.requester, summary);
}
