from app.frontend.settings import (
    load_auto_play_setting,
    load_dual_slider_setting,
    save_auto_play_setting,
    save_dual_slider_setting,
)
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from app.frontend.store import Store


class AudioSettings(QWidget):
    def __init__(self):
        super().__init__()
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.main_layout.setContentsMargins(0, 0, 0, 0)

        is_auto_play = load_auto_play_setting()
        self.auto_play = QPushButton(text="Auto Play")
        self.auto_play.setCheckable(True)
        self.auto_play.setChecked(is_auto_play)
        self.auto_play.clicked.connect(
            lambda x=not is_auto_play: self.update_auto_play(x)
        )
        self.auto_play.setToolTip("Sample will play on first click if enabled")
        self.main_layout.addWidget(self.auto_play)

        is_dual_slider = load_dual_slider_setting()
        self.dual_slider = QPushButton(text="Dual Search")
        self.dual_slider.setCheckable(True)
        self.dual_slider.setChecked(is_dual_slider)
        self.dual_slider.clicked.connect(
            lambda x=not is_dual_slider: self.update_dual_slider(x)
        )
        self.dual_slider.setToolTip("Both Width and Frequency sliders will be active to filter your results more")
        self.main_layout.addWidget(self.dual_slider)

    def update_auto_play(self, value: bool):
        self.auto_play.setChecked(value)
        save_auto_play_setting(value)

    def update_dual_slider(self, value: bool):
        self.dual_slider.setChecked(value)
        save_dual_slider_setting(value)
        if value:
            self.set_dual_search()
        else:
            self.bypass_dual_search()

    def update_value(self, attr: str, value):
        if hasattr(self, attr):
            setattr(self, attr, value)

    def set_dual_search(self):
        store = Store()
        if store._state.stereo_width is None:
            store.set_state("stereo_width", 0)
        if store._state.spectral_centroid is None:
            store.set_state("spectral_centroid", 40)

    def bypass_dual_search(self):
        store = Store()
        store.set_state("stereo_width", None)
        store.set_state("spectral_centroid", None)


