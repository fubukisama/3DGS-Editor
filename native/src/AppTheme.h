#pragma once

#include <QString>

class QApplication;
class QScreen;

namespace gsw {

class AppTheme final {
public:
  static int loadScalePercent(const QScreen *screen);
  static int recommendedScalePercent(const QScreen *screen);
  static void apply(QApplication &application, int scalePercent, bool persist);
  static int scaled(int value, int scalePercent);

private:
  static QString styleSheet(int scalePercent);
};

} // namespace gsw
