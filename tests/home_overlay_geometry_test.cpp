// Unit tests for where the desktop layout's Basecamp overlay puts its panel
// (src/HomeOverlayGeometry.h, basecamp-experiments#43): centred, 840 to 1000
// px wide, the height between the top bar and the dock, never off the window.
//
// Run: nix build .#unit-tests -L

#include "HomeOverlayGeometry.h"

#include <QtTest/QtTest>

class HomeOverlayGeometryTest : public QObject {
    Q_OBJECT

private slots:
    void laptopIsCentredBetweenTheBounds()
    {
        const QRect p = HomeOverlayGeometry::panel(QSize(1280, 800));
        QCOMPARE(p.width(), 896);
        QCOMPARE(p.x(), (1280 - 896) / 2);
        QCOMPARE(p.y(), HomeOverlayGeometry::kEdge);
        QCOMPARE(p.height(), 800 - 2 * HomeOverlayGeometry::kEdge);
    }

    void staysBetweenTheBarAndTheDock()
    {
        const QRect p = HomeOverlayGeometry::panel(QSize(1280, 800), 30, 92);
        QCOMPARE(p.top(), 30 + HomeOverlayGeometry::kEdge);
        QCOMPARE(p.y() + p.height(), 800 - 92 - HomeOverlayGeometry::kEdge);
    }

    void wideScreenStopsAtTheMaximum()
    {
        const QRect p = HomeOverlayGeometry::panel(QSize(1920, 1080));
        QCOMPARE(p.width(), HomeOverlayGeometry::kMaxWidth);
        QCOMPARE(p.center().x(), QRect(0, 0, 1920, 1080).center().x());
    }

    void smallWindowKeepsTheMinimumUntilTheEdges()
    {
        QCOMPARE(HomeOverlayGeometry::panel(QSize(1000, 700)).width(), HomeOverlayGeometry::kMinWidth);
        const QRect p = HomeOverlayGeometry::panel(QSize(800, 600));
        QCOMPARE(p.width(), 800 - 2 * HomeOverlayGeometry::kEdge);
        QCOMPARE(p.x(), HomeOverlayGeometry::kEdge);
    }

    void contentSitsInsideThePanel()
    {
        const QSize area(1440, 900);
        const QRect p = HomeOverlayGeometry::panel(area, 30, 92);
        const QRect c = HomeOverlayGeometry::content(area, 30, 92);
        QVERIFY(p.contains(c));
        QCOMPARE(c.x() - p.x(), HomeOverlayGeometry::kInset);
        QCOMPARE(p.bottom() - c.bottom(), HomeOverlayGeometry::kInset);
    }

    void tinyAreaNeverGoesNegative()
    {
        const QRect p = HomeOverlayGeometry::panel(QSize(20, 20), 30, 92);
        QVERIFY(p.width() >= 0);
        QVERIFY(p.height() >= 0);
    }
};

QTEST_GUILESS_MAIN(HomeOverlayGeometryTest)
#include "home_overlay_geometry_test.moc"
