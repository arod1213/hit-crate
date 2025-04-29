from typing import Optional

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QHBoxLayout, QSlider

from app.frontend.store import Store, StoreState


class Slider(QSlider):
    def __init__(
        self,
    ):
        super().__init__(orientation=Qt.Orientation.Horizontal)

        self.setMinimum(50)
        self.setMaximum(5000)

        self.store = Store()
        self.store.subscribe("filters", self.set_state)
        self.valueChanged.connect(self.update_store)

    def set_state(self, state: StoreState):
        self.setValue(state.filters.spectral_centroid)

    def update_store(self):
        self.store.update_filters("spectral_centroid", self.value())
