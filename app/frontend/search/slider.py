from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QHBoxLayout, QLabel, QSlider, QWidget

from app.frontend.store import Store, StoreState


class Slider(QWidget):
    def __init__(
        self,
    ):
        super().__init__()

        layout = QHBoxLayout(self)
        self.left_label = QLabel("dark")
        layout.addWidget(self.left_label)

        self.slider = QSlider(orientation=Qt.Orientation.Horizontal)
        self.slider.setMinimum(35)
        self.slider.setMaximum(8000)
        layout.addWidget(self.slider)

        self.left_label = QLabel("bright")
        layout.addWidget(self.left_label)

        self.store = Store()
        self.store.subscribe("filters", self.set_state)
        self.slider.sliderReleased.connect(self.update_store)

    def set_state(self, state: StoreState):
        self.slider.setValue(state.filters.spectral_centroid)

    def update_store(self):
        print(f"value is {self.slider.value}")
        self.store.update_filters("spectral_centroid", self.slider.value())
