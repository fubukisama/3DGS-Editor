#pragma once

#include <QString>
#include <QStringList>

namespace gsw {

struct UntitledWorkspaceSearchOptions final {
  QString configuredRoot;
  QString systemRoot;
  QStringList preferredRoots;
  QStringList mountedRoots;
  QString fallbackRoot;
};

[[nodiscard]] QString findUntitledWorkspaceBase(
    const UntitledWorkspaceSearchOptions &options,
    QString *errorMessage = nullptr);

[[nodiscard]] QString defaultUntitledWorkspaceBase(
    QString *errorMessage = nullptr);

} // namespace gsw
