from typing import Optional

from app.backend.models import Sample
from app.frontend.store import Store, StoreState
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QWidget,
)


class Info(QWidget):
    def __init__(self, parent=None, sample: Optional[Sample] = None):
        super().__init__(parent)
        self.sample = sample

        # Create layout
        self._layout = QHBoxLayout(self)
        self._layout.setContentsMargins(0, 0, 0, 0)

        self.store = Store()
        self.store.subscribe("selected_sample", self.set_info)

        # Call set_info initially to display "N/A"
        self.set_info(self.store._state)  # Pass the current state

        self.setLayout(self._layout)

    def set_info(self, state: StoreState):
        sample = state.selected_sample

        name = "No sample selected"
        format = ""
        duration = ""
        width = ""

        if sample is not None:
            name = sample.name
            format = sample.format.value
            # duration = f"{sample.duration:.2f}s"
            duration = f"{sample.spectral_centroid:.2f} {sample.rolloff}"
            width = f"Width: {sample.stereo_width:.2f}"

        self.clear_layout()
        # format = AudioFormat.from_value(sample.format)

        duration_widget = QLabel(f"{duration}")
        duration_widget.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self._layout.addWidget(duration_widget, stretch=1)

        name_widget = QLabel(f"{name}{format}")
        name_widget.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._layout.addWidget(name_widget, stretch=1)

        width_widget = QLabel(f"{width}")
        width_widget.setAlignment(Qt.AlignmentFlag.AlignRight)
        self._layout.addWidget(width_widget, stretch=1)

        self.setLayout(self._layout)

    def clear_layout(self):
        while self._layout.count():
            item = self._layout.takeAt(0)
            if item is not None and item.widget() is not None:
                item.widget().deleteLater()  # type: ignore
