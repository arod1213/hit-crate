from typing import Optional

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QIcon
import numpy as np
from app.frontend.components import Slider
from app.frontend.components.wave_display import WaveDisplay
from app.frontend.routes.browser.search.sort_slider import SortSlider
from app.frontend.store import Store, StoreState
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QPushButton,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from .results import Info, ResultList
from .search import Filters, SearchInput
from .search.actions import SearchAllTrigger


class Browser(QWidget):
    def __init__(self):
        super().__init__()

        self.store = Store()
        self.waveform: Optional[np.ndarray] = None

        self.setMinimumWidth(400)
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Preferred
        )

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

        tonal_slider = SortSlider(
            subscribe_to="spectral_centroid",
        )
        main_layout.addWidget(tonal_slider)

        info = Info()
        main_layout.addWidget(info)
        results = ResultList()
        main_layout.addWidget(results)

        # label for where to search
        self.path = QPushButton(text="searching all..")
        self.path.setStyleSheet("""
            QPushButton {
            background-color: transparent;
            border: 0px solid #ffffff;
            font-weight: normal;
            color: #333333;
            padding: 0px;
            margin: 0px;
            }
        """)
        self.store.subscribe("curr_path", self.update_path)
        self.path.clicked.connect(self.reset_path)
        main_layout.addWidget(self.path, alignment=Qt.AlignmentFlag.AlignHCenter)

        bottom_widget = QWidget()
        bottom_layout = QHBoxLayout(bottom_widget)
        bottom_layout.setContentsMargins(0, 0, 0, 0)
        output_slider = Slider(
            subscribe_to="lufs_target",
            min_value=-60,
            max_value=-15,
            text_left="quiet",
            text_right="loud",
        )
        dirs_icon = QIcon('assets/list-icon.svg')
        dirs_button = QPushButton(text='', icon=dirs_icon)
        dirs_button.clicked.connect(lambda: self.store.set_state(
            "show_dirs", not self.store._state.show_dirs
        ))
        dirs_button.setCheckable(False)
        dirs_button.setStyleSheet("""
            QPushButton {
                background-color: #e4e6eb;
                border-radius: 10px;
                border: 0px solid #000000;
            }
        """)
        bottom_layout.addWidget(dirs_button)
        bottom_layout.addWidget(output_slider)
        main_layout.addWidget(bottom_widget)

        # initialize results
        self.store.set_state("search_key", "")

    def reset_path(self):
        self.store.set_state("curr_path", None)

    def update_path(self, state: StoreState):
        path = state.curr_path
        if path is None:
            text = 'searching all..'
        else:
            last_two = path.parts[-2:]
            text = "/".join(last_two)
        self.path.setText(text)
