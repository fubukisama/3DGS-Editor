#pragma once

#include <QProcessEnvironment>
#include <QString>

namespace gsw {

struct ImportEnvironmentProbeResult {
  bool ready = false;
  QString python;
  QString videoBackend;
  QString errorMessage;
};

class ImportEnvironmentProbe final {
public:
  [[nodiscard]] static ImportEnvironmentProbeResult
  run(const QString &python, const QString &backendRoot, bool requireVideo,
      const QProcessEnvironment &environment, int timeoutMilliseconds = 60000);
};

} // namespace gsw
