#include "BackendLocator.h"

#include <QDir>
#include <QFileInfo>

namespace gsw {
namespace {

bool hasBackendMarkers(const QString &directoryPath) {
  const QDir directory(directoryPath);
  static const QStringList markers = {
      QStringLiteral("native/worker/gsw_worker.py"),
      QStringLiteral("native/worker/import_preflight.py"),
      QStringLiteral("crop_editor/server.py"),
      QStringLiteral("crop_editor/video_extract.py"),
      QStringLiteral("scripts/check_3dgs_env.ps1"),
      QStringLiteral("gaussian-splatting/train.py"),
  };

  for (const QString &marker : markers) {
    if (!QFileInfo(directory.filePath(marker)).isFile()) {
      return false;
    }
  }
  return true;
}

QString validatedRoot(const QString &directoryPath) {
  if (!QDir::isAbsolutePath(directoryPath)) {
    return {};
  }

  const QString cleanPath = QDir::cleanPath(directoryPath);
  if (!QFileInfo(cleanPath).isDir() || !hasBackendMarkers(cleanPath)) {
    return {};
  }
  return cleanPath;
}

} // namespace

QString BackendLocator::findRepositoryRoot(const QString &applicationDirectory,
                                           const QString &configuredRoot) {
  if (!configuredRoot.isEmpty()) {
    return validatedRoot(configuredRoot);
  }

  if (!QDir::isAbsolutePath(applicationDirectory)) {
    return {};
  }

  QDir candidate(QDir::cleanPath(applicationDirectory));
  constexpr int maximumParentLevels = 10;
  for (int level = 0; level <= maximumParentLevels; ++level) {
    const QString located = validatedRoot(candidate.path());
    if (!located.isEmpty()) {
      return located;
    }
    if (level == maximumParentLevels || !candidate.cdUp()) {
      break;
    }
  }
  return {};
}

QString BackendLocator::findGaussianPython(const QString &repositoryRoot) {
  QStringList candidates;
  const QStringList configuredPrefixes = {
      qEnvironmentVariable("GAUSSIAN_SPLATTING_CONDA_PREFIX"),
      qEnvironmentVariable("GS_CONDA_PREFIX")};
  for (const QString &configured : configuredPrefixes) {
    if (!configured.isEmpty()) {
      candidates.append(QDir(configured).filePath(QStringLiteral("python.exe")));
    }
  }

  const QString activeCondaPrefix = qEnvironmentVariable("CONDA_PREFIX");
  if (QFileInfo(activeCondaPrefix).fileName().compare(
          QStringLiteral("gaussian_splatting"), Qt::CaseInsensitive) == 0) {
    candidates.append(QDir(activeCondaPrefix).filePath(QStringLiteral("python.exe")));
  }

  const QString driveRoot = QDir(repositoryRoot).rootPath();
  const QString home = QDir::homePath();
  const QStringList conventionalPrefixes = {
      QDir(driveRoot).filePath(QStringLiteral("miniforge3/envs/gaussian_splatting")),
      QDir(driveRoot).filePath(QStringLiteral("conda/envs/gaussian_splatting")),
      QDir(driveRoot).filePath(QStringLiteral("anaconda/envs/gaussian_splatting")),
      QDir(driveRoot).filePath(QStringLiteral("anaconda3/envs/gaussian_splatting")),
      QDir(home).filePath(QStringLiteral("miniforge3/envs/gaussian_splatting")),
      QDir(home).filePath(QStringLiteral("miniconda3/envs/gaussian_splatting")),
      QDir(home).filePath(QStringLiteral("anaconda3/envs/gaussian_splatting")),
  };
  for (const QString &prefix : conventionalPrefixes) {
    candidates.append(QDir(prefix).filePath(QStringLiteral("python.exe")));
  }

  for (const QString &candidate : candidates) {
    if (QFileInfo(candidate).isFile()) {
      return QDir::toNativeSeparators(candidate);
    }
  }
  return {};
}

} // namespace gsw
