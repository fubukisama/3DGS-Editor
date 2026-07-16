#include "AppTheme.h"

#include <QApplication>
#include <QFont>
#include <QGuiApplication>
#include <QScreen>
#include <QSettings>
#include <QString>

#include <algorithm>

namespace gsw {

namespace {
constexpr int kMinimumScale = 75;
constexpr int kMaximumScale = 125;

int clampScale(const int value) {
  return std::clamp(value, kMinimumScale, kMaximumScale);
}
} // namespace

int AppTheme::recommendedScalePercent(const QScreen *screen) {
  if (screen == nullptr) {
    return 90;
  }

  const int logicalHeight = screen->availableGeometry().height();
  if (logicalHeight <= 820) {
    return 80;
  }
  if (logicalHeight <= 1080) {
    return 85;
  }
  if (logicalHeight <= 1440) {
    return 90;
  }
  return 100;
}

int AppTheme::loadScalePercent(const QScreen *screen) {
  QSettings settings;
  return clampScale(settings.value(QStringLiteral("ui/scalePercent"), recommendedScalePercent(screen)).toInt());
}

int AppTheme::scaled(const int value, const int scalePercent) {
  return std::max(1, qRound(static_cast<double>(value) * clampScale(scalePercent) / 100.0));
}

void AppTheme::apply(QApplication &application, const int scalePercent, const bool persist) {
  const int scale = clampScale(scalePercent);
  QFont font(QStringLiteral("Microsoft YaHei UI"));
  font.setPointSizeF(9.0 * scale / 100.0);
  font.setStyleStrategy(QFont::PreferAntialias);
  application.setFont(font);
  application.setStyleSheet(styleSheet(scale));
  application.setProperty("gswUiScalePercent", scale);

  if (persist) {
    QSettings settings;
    settings.setValue(QStringLiteral("ui/scalePercent"), scale);
  }
}

QString AppTheme::styleSheet(const int scalePercent) {
  QString css = QStringLiteral(R"CSS(
QWidget {
  background: #1b1d1f;
  color: #e7e9ea;
  selection-background-color: #327e74;
  selection-color: #ffffff;
}
QMainWindow, QDialog { background: #17191b; }
QMenuBar {
  background: #202326;
  border-bottom: 1px solid #34383c;
  padding: @MENU_PAD@px;
}
QMenuBar::item { padding: @MENU_ITEM_V@px @MENU_ITEM_H@px; background: transparent; }
QMenuBar::item:selected { background: #303438; }
QMenu {
  background: #24272a;
  border: 1px solid #41464b;
  padding: 4px;
}
QMenu::item { padding: @MENU_ROW_V@px @MENU_ROW_H@px; border-radius: 3px; }
QMenu::item:selected { background: #356e67; }
QMenu::separator { height: 1px; background: #3b3f43; margin: 4px 8px; }
QToolBar {
  background: #202326;
  border: 0;
  border-bottom: 1px solid #34383c;
  spacing: @TOOL_GAP@px;
  padding: @TOOL_PAD@px;
}
QToolBar::separator { width: 1px; background: #3b3f43; margin: 4px 6px; }
QToolButton {
  background: transparent;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: @BUTTON_PAD@px;
}
QToolButton:hover { background: #303438; border-color: #444a4f; }
QToolButton:pressed, QToolButton:checked { background: #315d58; border-color: #4a9a8f; }
QToolButton:disabled { color: #676d72; }
QPushButton {
  min-height: @CONTROL_HEIGHT@px;
  padding: 0 @CONTROL_PAD@px;
  background: #2a2e31;
  border: 1px solid #454a4f;
  border-radius: 4px;
}
QPushButton:hover { background: #34383c; border-color: #5a6268; }
QPushButton:pressed { background: #315d58; border-color: #4a9a8f; }
QPushButton:disabled { color: #6f7478; background: #242629; border-color: #34373a; }
QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox {
  min-height: @CONTROL_HEIGHT@px;
  background: #151719;
  border: 1px solid #41464b;
  border-radius: 4px;
  padding: 0 @INPUT_PAD@px;
}
QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus, QComboBox:focus {
  border-color: #55b2a5;
}
QComboBox::drop-down { border: 0; width: @COMBO_ARROW@px; }
QAbstractItemView {
  background: #191b1d;
  alternate-background-color: #1e2123;
  border: 0;
  outline: 0;
}
QTreeView::item, QTableView::item { min-height: @ROW_HEIGHT@px; }
QTreeView::item:hover, QTableView::item:hover { background: #282c2f; }
QTreeView::item:selected, QTableView::item:selected { background: #315d58; }
QHeaderView::section {
  background: #24272a;
  color: #b9bec2;
  border: 0;
  border-right: 1px solid #35393d;
  border-bottom: 1px solid #35393d;
  padding: @HEADER_PAD@px;
}
QDockWidget { color: #dfe2e4; }
QDockWidget::title {
  background: #222528;
  border-bottom: 1px solid #363a3e;
  padding: @DOCK_PAD@px;
  text-align: left;
}
QTabWidget::pane { border: 0; border-top: 1px solid #373b3f; }
QTabBar::tab {
  background: #202326;
  color: #aeb4b8;
  padding: @TAB_V@px @TAB_H@px;
  border: 0;
  border-right: 1px solid #34383c;
}
QTabBar::tab:selected { color: #ffffff; background: #2a2e31; border-top: 2px solid #55b2a5; }
QTabBar::tab:hover:!selected { background: #272a2d; }
QPlainTextEdit {
  background: #111315;
  color: #ced3d6;
  border: 0;
  font-family: "Cascadia Mono", "Consolas";
}
QScrollBar:vertical { background: #191b1d; width: @SCROLL@px; margin: 0; }
QScrollBar::handle:vertical { background: #484d51; min-height: 24px; border-radius: 4px; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QScrollBar:horizontal { background: #191b1d; height: @SCROLL@px; margin: 0; }
QScrollBar::handle:horizontal { background: #484d51; min-width: 24px; border-radius: 4px; }
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal { width: 0; }
QStatusBar { background: #202326; border-top: 1px solid #34383c; color: #aeb4b8; }
QStatusBar::item { border: 0; }
QLabel#sectionTitle {
  color: #d9dddf;
  font-weight: 600;
  padding-top: @SECTION_TOP@px;
  padding-bottom: @SECTION_BOTTOM@px;
  border-bottom: 1px solid #383c40;
}
QLabel#mutedLabel { color: #949ba0; }
QLabel#statusGood { color: #66c1a8; }
QLabel#statusWarn { color: #d9ad5b; }
QFrame#inspectorPanel { background: #1b1d1f; }
QSplitter::handle { background: #34383c; }
QToolTip { background: #2c3033; color: #ffffff; border: 1px solid #555b60; padding: 4px; }
)CSS");

  const auto replace = [&css, scalePercent](const QString &token, const int baseValue) {
    css.replace(token, QString::number(AppTheme::scaled(baseValue, scalePercent)));
  };
  replace(QStringLiteral("@MENU_PAD@"), 2);
  replace(QStringLiteral("@MENU_ITEM_V@"), 5);
  replace(QStringLiteral("@MENU_ITEM_H@"), 9);
  replace(QStringLiteral("@MENU_ROW_V@"), 6);
  replace(QStringLiteral("@MENU_ROW_H@"), 26);
  replace(QStringLiteral("@TOOL_GAP@"), 2);
  replace(QStringLiteral("@TOOL_PAD@"), 3);
  replace(QStringLiteral("@BUTTON_PAD@"), 5);
  replace(QStringLiteral("@CONTROL_HEIGHT@"), 26);
  replace(QStringLiteral("@CONTROL_PAD@"), 10);
  replace(QStringLiteral("@INPUT_PAD@"), 7);
  replace(QStringLiteral("@COMBO_ARROW@"), 22);
  replace(QStringLiteral("@ROW_HEIGHT@"), 25);
  replace(QStringLiteral("@HEADER_PAD@"), 6);
  replace(QStringLiteral("@DOCK_PAD@"), 7);
  replace(QStringLiteral("@TAB_V@"), 7);
  replace(QStringLiteral("@TAB_H@"), 12);
  replace(QStringLiteral("@SCROLL@"), 10);
  replace(QStringLiteral("@SECTION_TOP@"), 9);
  replace(QStringLiteral("@SECTION_BOTTOM@"), 6);
  return css;
}

} // namespace gsw
