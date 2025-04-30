from PyQt6.QtWidgets import (
    QHBoxLayout,
    QWidget,
)

from app.frontend.settings.toggle_view import ToggleView
from app.frontend.store import Store

from .filter_button import FilterButton


class Filters(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)

        layout = QHBoxLayout(self)
        self.store = Store()

        byWidth = self.store._state.filters.by_width
        byFreq = self.store._state.filters.by_freq
        self.width_button = FilterButton(
            text="Width",
            pressed=byWidth,
            attribute="by_width",
            icon="app/frontend/assets/stereo-icon.svg",
        )
        layout.addWidget(self.width_button)

        self.freq_button = FilterButton(
            text="Frequency",
            pressed=byFreq,
            attribute="by_freq",
            icon="app/frontend/assets/freq-icon.svg",
        )
        layout.addWidget(self.freq_button)

        toggle_view = ToggleView()
        layout.addWidget(toggle_view)
