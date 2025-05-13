from app.frontend.settings import (
    load_auto_play_setting,
    save_auto_play_setting,
)
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QPushButton,
    QVBoxLayout,
    QWidget,
)


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
        self.main_layout.addWidget(self.auto_play)

    def update_auto_play(self, value: bool):
        self.auto_play.setChecked(value)
        save_auto_play_setting(value)

    def update_value(self, attr: str, value):
        if hasattr(self, attr):
            setattr(self, attr, value)
