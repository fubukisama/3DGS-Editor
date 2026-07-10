#pragma once

#include <QElapsedTimer>
#include <QMatrix4x4>
#include <QOpenGLFunctions>
#include <QOpenGLWidget>
#include <QPoint>
#include <QPointF>
#include <QString>
#include <QVector3D>

#include <optional>

class QMouseEvent;
class QPainter;
class QWheelEvent;

namespace gsw {

class NativeViewport final : public QOpenGLWidget, protected QOpenGLFunctions {
  Q_OBJECT

public:
  enum class InteractionMode {
    Inspect,
    Select,
    Rectangle,
    Lasso,
    Crop
  };

  explicit NativeViewport(QWidget *parent = nullptr);

  void setProjectLabel(const QString &label);
  void setScene(const QString &scenePath, qint64 gaussianCount);
  void setInteractionMode(InteractionMode mode);
  void resetCamera();

signals:
  void frameTimeChanged(double milliseconds);

protected:
  void initializeGL() override;
  void resizeGL(int width, int height) override;
  void paintGL() override;
  void mousePressEvent(QMouseEvent *event) override;
  void mouseMoveEvent(QMouseEvent *event) override;
  void mouseReleaseEvent(QMouseEvent *event) override;
  void wheelEvent(QWheelEvent *event) override;

private:
  [[nodiscard]] QVector3D cameraPosition() const;
  [[nodiscard]] std::optional<QPointF> projectPoint(const QVector3D &point,
                                                    const QMatrix4x4 &viewProjection) const;
  void drawGrid(QPainter &painter, const QMatrix4x4 &viewProjection);
  void drawOverlay(QPainter &painter, double frameMilliseconds);
  void drawAxisGizmo(QPainter &painter);

  QString mProjectLabel;
  QString mScenePath;
  qint64 mGaussianCount = 0;
  InteractionMode mMode = InteractionMode::Inspect;
  QPoint mLastMousePosition;
  Qt::MouseButtons mPressedButtons;
  QVector3D mTarget = QVector3D(0.0F, 0.0F, 0.0F);
  float mYawDegrees = 42.0F;
  float mPitchDegrees = 24.0F;
  float mDistance = 12.0F;
  QElapsedTimer mFrameTimer;
  double mSmoothedFrameMilliseconds = 0.0;
};

} // namespace gsw
