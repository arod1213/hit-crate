from pathlib import Path
from typing import Optional

from PyQt6.QtCore import QMimeData, QUrl, Qt
from PyQt6.QtGui import QDrag, QIcon, QKeySequence, QMouseEvent, QShortcut
from PyQt6.QtWidgets import (
    QListWidget,
    QListWidgetItem,
    QVBoxLayout,
    QWidget,
)
from sqlmodel import Session

from app.backend.db import engine
from app.backend.schemas import SampleSimilarInput
from app.backend.services import SampleService

# from app.frontend.components.loading import LoadingIndicator
from app.frontend.components.draggable_list import DraggableList
from app.frontend.results.result_item import ResultItem
from app.frontend.store import Store, StoreState


class Results(QWidget):
    def __init__(self):
        super().__init__()
        self.store = Store()
        self.store.subscribe("results", self.refresh_results)

        # Create layout
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        # Create results list
        self.results_list = DraggableList()
        self.results_list.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.results_list.setMinimumHeight(300)
        self.results_list.itemClicked.connect(self.select_sample)
        layout.addWidget(self.results_list)

        self.setLayout(layout)

        self.results_list.currentItemChanged.connect(self.select_sample)

        self.store.subscribe("search_key", self.reset_scrollbar)
        self.store.subscribe("spectral_centroid", self.reset_scrollbar)

        self.backslash_shortcut = QShortcut(
            QKeySequence(Qt.Key.Key_Backslash), self
        )
        self.backslash_shortcut.activated.connect(self.find_similar)

    def select_sample(self, item):
        if item is None:
            return
        file_data = item.data(Qt.ItemDataRole.UserRole)
        self.store.set_state("selected_sample", file_data)

    def refresh_results(self, state: StoreState):
        self.results_list.clear()
        data = state.results
        if data is None:
            return
        for sample in data:
            item = QListWidgetItem(sample.name)
            item.setData(Qt.ItemDataRole.UserRole, sample)

            if sample.is_favorite:
                item.setIcon(QIcon("app/frontend/assets/heart-icon-fill.svg"))

            self.results_list.addItem(item)

    def reset_scrollbar(self, _: Optional[StoreState]):
        scroll_bar = self.results_list.verticalScrollBar()
        if scroll_bar is not None:
            scroll_bar.setValue(0)
        return

    def find_similar(self):
        sample = self.store._state.selected_sample
        if sample is None:
            return

        # self.loading_bar.toggle_loading(True)

        with Session(engine) as db_session:
            data = SampleService(db_session).query_similar(
                path=Path(sample.path),
                input=SampleSimilarInput(
                    name=self.store._state.search_key,
                    byWidth=self.store._state.filters.by_width,
                    byFreq=self.store._state.filters.by_freq,
                ),
            )
            self.store.set_state("results", data)

        self.reset_scrollbar(None)
        # self.loading_bar.toggle_loading(False)
        # return data

