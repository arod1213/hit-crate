from pathlib import Path
from typing import Optional

import numpy as np
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QKeySequence, QShortcut
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QMainWindow,
    QPushButton,
    QSplitter,
    QVBoxLayout,
    QWidget,
)

from app.frontend.browser.main import Browser
from app.frontend.search.slider import Slider
from app.frontend.settings.main import Settings
from app.frontend.settings.open_dir import OpenDir

from .audio_engine import AudioEngine
from .results.info import Info
from .results.results import Results
from .search.filters import Filters
from .search.search_input import SearchInput
from .store import Store
from .wave_display import WaveDisplay


class BrowserApp(QMainWindow):
    def __init__(self):
        super().__init__()

        self.browser_widget = Browser()
        self.settings_widget = Settings()
        self.setup_ui()
        self.setStyleSheet(self.load_stylesheet())

        # Create central widget

    def load_stylesheet(self) -> str:
        print("LOADING")
        # Resolve style.qss relative to this file
        style_path = Path(__file__).parent / "style.qss"
        if style_path.exists():
            return style_path.read_text()
        else:
            print("Warning: style.qss not found")
            return ""

    def setup_ui(self):
        self.setWindowTitle("Hit Crate")
        self.setMinimumSize(450, 450)

        self.setCentralWidget(self.browser_widget)

    def run(self):
        self.show()
