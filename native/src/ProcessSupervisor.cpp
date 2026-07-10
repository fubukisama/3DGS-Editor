#include "ProcessSupervisor.h"

#include <QProcessEnvironment>
#include <QTimer>

namespace gsw {

ProcessSupervisor::ProcessSupervisor(QObject *parent) : QObject(parent) {
  mProcess.setProcessChannelMode(QProcess::MergedChannels);

  connect(&mProcess, &QProcess::readyReadStandardOutput, this, &ProcessSupervisor::drainOutput);
  connect(&mProcess, &QProcess::started, this, [this]() {
    emit taskStarted(mActiveTask);
    emit runningChanged(true);
  });
  connect(&mProcess, &QProcess::errorOccurred, this, [this](const QProcess::ProcessError error) {
    if (error == QProcess::FailedToStart) {
      emit outputReady(tr("Failed to start process: %1\n").arg(mProcess.errorString()));
      const QString failedTask = mActiveTask;
      mActiveTask.clear();
      emit taskFinished(failedTask, -1, false);
      emit runningChanged(false);
    }
  });
  connect(&mProcess, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
          [this](const int exitCode, const QProcess::ExitStatus exitStatus) {
            drainOutput();
            const QString finishedTask = mActiveTask;
            const bool succeeded = exitStatus == QProcess::NormalExit && exitCode == 0;
            mActiveTask.clear();
            emit taskFinished(finishedTask, exitCode, succeeded);
            emit runningChanged(false);
          });
}

bool ProcessSupervisor::isRunning() const { return mProcess.state() != QProcess::NotRunning; }
QString ProcessSupervisor::activeTask() const { return mActiveTask; }

bool ProcessSupervisor::start(const QString &taskName, const QString &program,
                              const QStringList &arguments, const QString &workingDirectory) {
  if (isRunning() || program.isEmpty()) {
    return false;
  }

  mActiveTask = taskName;
  if (!workingDirectory.isEmpty()) {
    mProcess.setWorkingDirectory(workingDirectory);
  }
  mProcess.setProcessEnvironment(QProcessEnvironment::systemEnvironment());
  mProcess.start(program, arguments, QIODevice::ReadOnly);
  return true;
}

void ProcessSupervisor::stop() {
  if (!isRunning()) {
    return;
  }

  emit outputReady(tr("Requesting task termination...\n"));
  mProcess.terminate();
  QTimer::singleShot(2500, this, [this]() {
    if (isRunning()) {
      emit outputReady(tr("Task did not stop in time; terminating it now.\n"));
      mProcess.kill();
    }
  });
}

void ProcessSupervisor::drainOutput() {
  const QByteArray bytes = mProcess.readAllStandardOutput();
  if (!bytes.isEmpty()) {
    emit outputReady(QString::fromUtf8(bytes));
  }
}

} // namespace gsw
