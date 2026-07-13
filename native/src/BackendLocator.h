#pragma once

#include <QString>

namespace gsw {

class BackendLocator final {
public:
  [[nodiscard]] static QString
  findRepositoryRoot(const QString &applicationDirectory,
                     const QString &configuredRoot = {});
  [[nodiscard]] static QString findGaussianPython(const QString &repositoryRoot);
};

} // namespace gsw
