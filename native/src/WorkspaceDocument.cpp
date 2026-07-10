#include "WorkspaceDocument.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSet>

namespace gsw {

namespace {
QString normalizedAbsolutePath(const QString &path) {
  return QDir::cleanPath(QFileInfo(path).absoluteFilePath());
}

void assignError(QString *target, const QString &message) {
  if (target != nullptr) {
    *target = message;
  }
}
} // namespace

bool PlyMetadata::looksLikeGaussianSplat() const {
  const QSet<QString> propertySet(properties.cbegin(), properties.cend());
  return propertySet.contains(QStringLiteral("opacity")) &&
         propertySet.contains(QStringLiteral("scale_0")) &&
         propertySet.contains(QStringLiteral("rot_0"));
}

WorkspaceDocument::WorkspaceDocument(QObject *parent) : QObject(parent) {}

bool WorkspaceDocument::hasProject() const { return !mRootPath.isEmpty(); }
bool WorkspaceDocument::isModified() const { return mModified; }
QString WorkspaceDocument::projectName() const { return mProjectName; }
QString WorkspaceDocument::rootPath() const { return mRootPath; }
QString WorkspaceDocument::projectFilePath() const { return mProjectFilePath; }
QString WorkspaceDocument::datasetPath() const { return mDatasetPath; }
QString WorkspaceDocument::scenePath() const { return mScenePath; }
qint64 WorkspaceDocument::imageCount() const { return mImageCount; }
PlyMetadata WorkspaceDocument::sceneMetadata() const { return mSceneMetadata; }

bool WorkspaceDocument::create(const QString &rootPath, QString *errorMessage) {
  const QFileInfo rootInfo(rootPath);
  if (!rootInfo.exists() || !rootInfo.isDir()) {
    assignError(errorMessage, tr("Project directory does not exist: %1").arg(rootPath));
    return false;
  }

  mRootPath = normalizedAbsolutePath(rootPath);
  mProjectName = QDir(mRootPath).dirName();
  if (mProjectName.isEmpty()) {
    mProjectName = QStringLiteral("Gaussian Scene Project");
  }
  mProjectFilePath.clear();
  mDatasetPath.clear();
  mScenePath.clear();
  mImageCount = 0;
  mSceneMetadata = {};
  setModified(true);
  emit changed();
  return true;
}

bool WorkspaceDocument::load(const QString &filePath, QString *errorMessage) {
  QFile file(filePath);
  if (!file.open(QIODevice::ReadOnly)) {
    assignError(errorMessage, tr("Unable to open project: %1").arg(file.errorString()));
    return false;
  }

  QJsonParseError parseError;
  const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
  if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
    assignError(errorMessage, tr("Invalid project file: %1").arg(parseError.errorString()));
    return false;
  }

  const QJsonObject root = document.object();
  const int schemaVersion = root.value(QStringLiteral("schemaVersion")).toInt();
  if (schemaVersion != 1) {
    assignError(errorMessage, tr("Unsupported project schema version: %1").arg(schemaVersion));
    return false;
  }

  mProjectFilePath = normalizedAbsolutePath(filePath);
  const QString storedRoot = root.value(QStringLiteral("rootPath")).toString();
  const QString projectDirectory = QFileInfo(mProjectFilePath).absolutePath();
  if (storedRoot.isEmpty()) {
    mRootPath = projectDirectory;
  } else if (QDir::isAbsolutePath(storedRoot)) {
    mRootPath = normalizedAbsolutePath(storedRoot);
  } else {
    mRootPath = QDir::cleanPath(QDir(projectDirectory).absoluteFilePath(storedRoot));
  }
  mProjectName = root.value(QStringLiteral("projectName")).toString(QDir(mRootPath).dirName());
  mDatasetPath = resolvePortablePath(root.value(QStringLiteral("datasetPath")).toString());
  mScenePath = resolvePortablePath(root.value(QStringLiteral("scenePath")).toString());
  mImageCount = countDatasetImages(mDatasetPath);
  mSceneMetadata = inspectPly(mScenePath);
  setModified(false);
  emit changed();
  return true;
}

bool WorkspaceDocument::save(const QString &filePath, QString *errorMessage) {
  if (!hasProject()) {
    assignError(errorMessage, tr("No project is open."));
    return false;
  }

  const QString targetPath = filePath.isEmpty() ? mProjectFilePath : normalizedAbsolutePath(filePath);
  if (targetPath.isEmpty()) {
    assignError(errorMessage, tr("A project file path is required."));
    return false;
  }

  QJsonObject root;
  root.insert(QStringLiteral("schemaVersion"), 1);
  root.insert(QStringLiteral("application"), QStringLiteral("Gaussian Scene Workbench"));
  root.insert(QStringLiteral("projectName"), mProjectName);
  const QString projectDirectory = QFileInfo(targetPath).absolutePath();
  const QString relativeRoot = QDir(projectDirectory).relativeFilePath(mRootPath);
  const QString storedRoot = !relativeRoot.startsWith(QStringLiteral("..")) && !QDir::isAbsolutePath(relativeRoot)
                                 ? relativeRoot
                                 : mRootPath;
  root.insert(QStringLiteral("rootPath"), storedRoot);
  root.insert(QStringLiteral("datasetPath"), makePortablePath(mDatasetPath));
  root.insert(QStringLiteral("scenePath"), makePortablePath(mScenePath));
  root.insert(QStringLiteral("updatedUtc"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

  QSaveFile output(targetPath);
  if (!output.open(QIODevice::WriteOnly)) {
    assignError(errorMessage, tr("Unable to save project: %1").arg(output.errorString()));
    return false;
  }
  output.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
  if (!output.commit()) {
    assignError(errorMessage, tr("Unable to commit project file: %1").arg(output.errorString()));
    return false;
  }

  mProjectFilePath = targetPath;
  setModified(false);
  emit changed();
  return true;
}

bool WorkspaceDocument::setDatasetPath(const QString &path, QString *errorMessage) {
  const QFileInfo info(path);
  if (!info.exists() || !info.isDir()) {
    assignError(errorMessage, tr("Dataset directory does not exist: %1").arg(path));
    return false;
  }
  mDatasetPath = normalizedAbsolutePath(path);
  mImageCount = countDatasetImages(mDatasetPath);
  setModified(true);
  emit changed();
  return true;
}

bool WorkspaceDocument::setScenePath(const QString &path, QString *errorMessage) {
  const PlyMetadata metadata = inspectPly(path, errorMessage);
  if (!metadata.valid) {
    return false;
  }
  mScenePath = normalizedAbsolutePath(path);
  mSceneMetadata = metadata;
  setModified(true);
  emit changed();
  return true;
}

PlyMetadata WorkspaceDocument::inspectPly(const QString &filePath, QString *errorMessage) {
  PlyMetadata metadata;
  if (filePath.isEmpty()) {
    return metadata;
  }

  QFile file(filePath);
  const QFileInfo info(filePath);
  metadata.fileSize = info.size();
  if (!file.open(QIODevice::ReadOnly)) {
    assignError(errorMessage, tr("Unable to open PLY file: %1").arg(file.errorString()));
    return metadata;
  }

  constexpr qint64 kMaximumHeaderBytes = 1024 * 1024;
  qint64 consumed = 0;
  bool firstLine = true;
  bool foundEndHeader = false;
  bool readingVertexProperties = false;

  while (!file.atEnd() && consumed < kMaximumHeaderBytes) {
    const QByteArray rawLine = file.readLine();
    consumed += rawLine.size();
    const QString line = QString::fromLatin1(rawLine).trimmed();

    if (firstLine) {
      firstLine = false;
      if (line != QStringLiteral("ply")) {
        assignError(errorMessage, tr("The selected file is not a PLY file."));
        return metadata;
      }
      continue;
    }

    if (line.startsWith(QStringLiteral("format "))) {
      metadata.format = line.section(QLatin1Char(' '), 1, 1);
    } else if (line.startsWith(QStringLiteral("element "))) {
      const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
      readingVertexProperties = parts.size() >= 3 && parts.at(1) == QStringLiteral("vertex");
      if (readingVertexProperties) {
        bool ok = false;
        const qint64 count = parts.at(2).toLongLong(&ok);
        if (ok) {
          metadata.vertexCount = count;
        }
      }
    } else if (readingVertexProperties && line.startsWith(QStringLiteral("property "))) {
      const QString propertyName = line.section(QLatin1Char(' '), -1);
      if (!propertyName.isEmpty()) {
        metadata.properties.append(propertyName);
      }
    } else if (line == QStringLiteral("end_header")) {
      foundEndHeader = true;
      break;
    }
  }

  if (!foundEndHeader || metadata.format.isEmpty()) {
    assignError(errorMessage, tr("The PLY header is incomplete or unsupported."));
    return metadata;
  }
  metadata.valid = true;
  return metadata;
}

qint64 WorkspaceDocument::countDatasetImages(const QString &directoryPath) {
  if (directoryPath.isEmpty() || !QFileInfo(directoryPath).isDir()) {
    return 0;
  }

  static const QSet<QString> extensions = {
      QStringLiteral("jpg"), QStringLiteral("jpeg"), QStringLiteral("png"),
      QStringLiteral("tif"), QStringLiteral("tiff"), QStringLiteral("bmp"),
      QStringLiteral("webp"), QStringLiteral("exr")};

  qint64 count = 0;
  QDirIterator iterator(directoryPath, QDir::Files | QDir::NoSymLinks, QDirIterator::Subdirectories);
  while (iterator.hasNext()) {
    const QFileInfo info(iterator.next());
    if (extensions.contains(info.suffix().toLower())) {
      ++count;
    }
  }
  return count;
}

void WorkspaceDocument::setModified(const bool modified) {
  if (mModified == modified) {
    return;
  }
  mModified = modified;
  emit modifiedChanged(mModified);
}

QString WorkspaceDocument::makePortablePath(const QString &absolutePath) const {
  if (absolutePath.isEmpty() || mRootPath.isEmpty()) {
    return absolutePath;
  }
  const QString relative = QDir(mRootPath).relativeFilePath(absolutePath);
  if (!relative.startsWith(QStringLiteral("..")) && !QDir::isAbsolutePath(relative)) {
    return relative;
  }
  return absolutePath;
}

QString WorkspaceDocument::resolvePortablePath(const QString &storedPath) const {
  if (storedPath.isEmpty() || QDir::isAbsolutePath(storedPath)) {
    return storedPath;
  }
  return QDir::cleanPath(QDir(mRootPath).absoluteFilePath(storedPath));
}

} // namespace gsw
