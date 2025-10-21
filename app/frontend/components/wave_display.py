from pathlib import Path

from PyQt6.QtCore import QMimeData, Qt, QUrl
from PyQt6.QtGui import QColor, QDrag, QMouseEvent, QPainter, QPen
from PyQt6.QtWidgets import QVBoxLayout, QWidget

import app.backend.utils.waveform as wv
from app.frontend.store import Store, StoreState


class WaveDisplay(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("WaveDisplay")
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.setMinimumHeight(100)
        self.waveform = None
        self.store = Store()
        self.store.subscribe("selected_sample", self.render_wave)
        self.setAcceptDrops(False)
        self.setMouseTracking(True)

    def render_wave(self, state: StoreState):
        sample = state.selected_sample
        if not sample:
            return
        waveform = wv.render_waveform(Path(sample.path))

        if waveform is None:
            return
        self.waveform = waveform
        self.update()

    def mousePressEvent(self, a0: QMouseEvent | None):
        sample = self.store._state.selected_sample
        if sample is None or a0 is None:
            return
        if a0.button() == Qt.MouseButton.LeftButton and sample.path:
            drag = QDrag(self)
            mime_data = QMimeData()

            mime_data.setUrls([QUrl.fromLocalFile(sample.path)])
            drag.setMimeData(mime_data)

            drag.exec(Qt.DropAction.CopyAction)

    def paintEvent(self, a0):
        if self.waveform is None:
            return

        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Set up drawing area
        rect = self.rect()
        center_y = rect.height() / 2

        # Set pen
        pen = QPen(QColor("#5BA7FF"))
        pen.setWidth(1)
        painter.setPen(pen)

        if self.waveform is None or self.waveform.size == 0:
            painter.drawText(
                rect,
                Qt.AlignmentFlag.AlignCenter,
                text="No waveform available",
            )
            return

        # Draw waveform
        points_per_pixel = max(1, len(self.waveform) // rect.width())
        x_scale = rect.width() / len(self.waveform)

        for i in range(0, len(self.waveform) - points_per_pixel, points_per_pixel):
            x1 = int(i * x_scale)
            y1 = int(center_y * (1 - self.waveform[i]))
            x2 = int((i + points_per_pixel) * x_scale)
            y2 = int(center_y * (1 - self.waveform[i + points_per_pixel]))
            painter.drawLine(x1, y1, x2, y2)
