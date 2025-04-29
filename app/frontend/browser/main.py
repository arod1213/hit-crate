from typing import Optional

import numpy as np
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QKeySequence, QShortcut
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QVBoxLayout,
    QWidget,
)

from app.frontend.search.slider import Slider
from app.frontend.settings.open_dir import OpenDir

from ..audio_engine import AudioEngine
from ..results.info import Info
from ..results.results import Results
from ..search.filters import Filters
from ..search.search_input import SearchInput
from ..store import Store
from ..wave_display import WaveDisplay


class Browser(QWidget):
    def __init__(self):
        super().__init__()

        self.store = Store()
        self.audio_player = AudioEngine()
        self.waveform: Optional[np.ndarray] = None

        main_layout = QVBoxLayout(self)

        search_widget = QWidget()
        search_layout = QHBoxLayout(search_widget)
        search_input = SearchInput()
        search_layout.addWidget(search_input, stretch=1)
        filters = Filters()
        search_layout.addWidget(filters)
        main_layout.addWidget(search_widget)

        # Initialize wave display
        waveform_container = QWidget()
        waveform_container.setObjectName("WaveDisplayContainer")
        waveform_layout = QVBoxLayout(waveform_container)
        waveform_layout.setContentsMargins(0, 0, 0, 0)
        waveform = WaveDisplay()
        waveform_layout.addWidget(waveform)
        main_layout.addWidget(waveform_container)

        slider = Slider()
        main_layout.addWidget(slider)

        info = Info()
        main_layout.addWidget(info)
        results = Results()
        main_layout.addWidget(results)

        self.space_shortcut = QShortcut(QKeySequence(Qt.Key.Key_Space), self)
        self.space_shortcut.activated.connect(self.play_sample)


    def play_sample(self):
        sample = self.store._state.selected_sample
        if sample is not None:
            self.audio_player.load_audio(sample)
            self.audio_player.play()
