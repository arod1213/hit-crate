from pathlib import Path

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QKeySequence, QShortcut
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
        self.results_list = QListWidget()
        self.results_list.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.results_list.setMinimumHeight(300)
        self.results_list.itemClicked.connect(self.select_sample)
        layout.addWidget(self.results_list)

        self.setLayout(layout)

        self.backslash_shortcut = QShortcut(
            QKeySequence(Qt.Key.Key_Backslash), self
        )
        self.backslash_shortcut.activated.connect(self.find_similar)

    def select_sample(self, item):
        file_data = item.data(Qt.ItemDataRole.UserRole)
        self.store.set_state("selected_sample", file_data)

    def refresh_results(self, state: StoreState):
        self.results_list.clear()
        data = state.results
        if data is None:
            return
        for file in data:
            item = QListWidgetItem(file.name)
            item.setData(Qt.ItemDataRole.UserRole, file)
            self.results_list.addItem(item)

    def find_similar(self):
        sample = self.store._state.selected_sample
        if sample is None:
            return
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
            return data
