from pathlib import Path
from typing import Optional

from app.backend.db import engine
from app.backend.models import Sample
from app.backend.schemas import SampleSimilarInput
from app.backend.services import SampleService
from app.frontend.audio_engine import AudioEngine
from app.frontend.components.draggable_list import DraggableList
from app.frontend.routes.browser.results.context_menu import ContextMenu
from app.frontend.settings import load_auto_play_setting
from app.frontend.store import Store, StoreState
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QIcon, QKeySequence, QShortcut
from PyQt6.QtWidgets import (
    QListWidgetItem,
    QVBoxLayout,
    QWidget,
)
from sqlmodel import Session


class ResultList(QWidget):
    def __init__(self):
        super().__init__()
        self.store = Store()
        self.store.subscribe("results", self.refresh_results)

        self.audio_player = AudioEngine()

        # Create layout
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        # Create results list
        self.results_list = DraggableList()
        self.results_list.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.results_list.setMinimumHeight(300)
        self.results_list.setContextMenuPolicy(
            Qt.ContextMenuPolicy.CustomContextMenu
        )
        self.results_list.customContextMenuRequested.connect(
            self.show_context_menu
        )
        layout.addWidget(self.results_list)

        self.setLayout(layout)

        self.store.subscribe("results", self.reset_scrollbar)

        # handle selection of sample
        self.results_list.currentItemChanged.connect(self.handle_select_sample)
        # self.results_list.itemClicked.connect(
        #     self.handle_select_sample
        # )

        self.backslash_shortcut = QShortcut(
            QKeySequence(Qt.Key.Key_Backslash), self
        )
        self.backslash_shortcut.activated.connect(self.find_similar)
        self.space_shortcut = QShortcut(QKeySequence(Qt.Key.Key_Space), self)
        self.space_shortcut.activated.connect(
            lambda x=None: self.play_sample(x)
        )

    def show_context_menu(self, position):
        item = self.results_list.itemAt(position)
        if item is None:
            return  # No item under cursor

        sample: Sample = item.data(Qt.ItemDataRole.UserRole)

        menu = ContextMenu(sample)
        menu.favorite_set.connect(lambda sample: self.set_item(item, sample))
        menu.exec(self.results_list.viewport().mapToGlobal(position))  # type: ignore

    def set_item(
        self, item: Optional[QListWidgetItem], sample: Sample
    ) -> QListWidgetItem:
        if item is None:
            item = QListWidgetItem(sample.name)
        item.setData(Qt.ItemDataRole.UserRole, sample)

        if sample.is_favorite:
            item.setIcon(QIcon("assets/heart-icon-fill.svg"))
        else:
            item.setIcon(QIcon(""))

        return item

    def handle_select_sample(self, item):
        if item is None:
            return
        file_data = item.data(Qt.ItemDataRole.UserRole)
        self.store.set_state("selected_sample", file_data)
        auto_play = load_auto_play_setting()
        if auto_play:
            self.play_sample(file_data)

    def play_sample(self, sample: Optional[Sample]):
        if sample is None:
            sample = self.store._state.selected_sample

        can_play = self.audio_player.load_audio(sample)
        if can_play:
            self.audio_player.play()
        else:
            self.audio_player.stop()

    def refresh_results(self, state: StoreState):
        self.results_list.clear()
        data = state.results
        if data is None:
            return
        for sample in data:
            item = self.set_item(None, sample)
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
