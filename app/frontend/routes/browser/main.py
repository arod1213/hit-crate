from typing import Optional

import numpy as np
from app.frontend.components import Slider
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QVBoxLayout,
    QWidget,
)

from .results import Info, ResultList
from .search import Filters, SearchInput
from .search.actions import SearchAllTrigger
from app.frontend.store import Store
from app.frontend.components.wave_display import WaveDisplay


class Browser(QWidget):
    def __init__(self):
        super().__init__()

        self.store = Store()
        self.waveform: Optional[np.ndarray] = None

        main_layout = QVBoxLayout(self)

        SearchAllTrigger()
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

        tonal_slider = Slider(
            subscribe_to="spectral_centroid",
            min_value=35,
            max_value=8000,
            text_left="dark",
            text_right="bright",
        )
        main_layout.addWidget(tonal_slider)

        info = Info()
        main_layout.addWidget(info)
        results = ResultList()
        main_layout.addWidget(results)

        output_slider = Slider(
            subscribe_to="lufs_target",
            min_value=-60,
            max_value=-15,
            text_left="quiet",
            text_right="loud",
        )
        main_layout.addWidget(output_slider)

        # initialize results
        self.store.set_state("search_key", "")
