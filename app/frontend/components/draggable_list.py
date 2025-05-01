from PyQt6.QtCore import QMimeData, QUrl, Qt
from PyQt6.QtGui import QDrag, QMouseEvent
from PyQt6.QtWidgets import QApplication, QListWidget

from app.frontend.store import Store


class DraggableList(QListWidget):
    def __init__(self):
        super().__init__()
        self.store = Store()

    def mousePressEvent(self, e: QMouseEvent | None) -> None:
        super().mousePressEvent(e)
        if e is None:
            return
        if e.button() == Qt.MouseButton.LeftButton:
            self._drag_start_pos = e.pos()

    def mouseMoveEvent(self, e: QMouseEvent | None) -> None:
        if e is None:
            return
        if (
            self._drag_start_pos is not None
            and (e.pos() - self._drag_start_pos).manhattanLength() > QApplication.startDragDistance()
        ):
            sample = self.store._state.selected_sample
            if sample and sample.path:
                drag = QDrag(self)
                mime_data = QMimeData()
                mime_data.setUrls([QUrl.fromLocalFile(sample.path)])
                drag.setMimeData(mime_data)
                drag.exec(Qt.DropAction.CopyAction)
            self._drag_start_pos = None  # Reset
        else:
            super().mouseMoveEvent(e)
