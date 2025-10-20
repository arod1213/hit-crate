from pathlib import Path

from app.backend.db import engine
from app.backend.models import Sample
from app.backend.schemas import SampleSimilarInput, SampleUpdateInput
from app.backend.services.hold import get_similar_samples, update_sample
from app.frontend.store import Store
from PyQt6.QtCore import pyqtSignal
from PyQt6.QtGui import QAction
from PyQt6.QtWidgets import QMenu
from sqlmodel import Session


class ContextMenu(QMenu):
    favorite_set = pyqtSignal(object)

    def __init__(self, sample: Sample):
        super().__init__()
        self.store = Store()

        self.sample = sample

        fav_action = QAction("Favorite", self)
        fav_action.triggered.connect(self.set_favorite)
        self.addAction(fav_action)

        similar_action = QAction("Find Similar", self)
        similar_action.triggered.connect(self.find_similar)
        self.addAction(similar_action)

        path_action = QAction("Show all in path", self)
        path_action.triggered.connect(self.show_in_path)
        self.addAction(path_action)

    def show_in_path(self):
        parent_path = Path(self.sample.path).parent
        self.store.set_state("curr_path", parent_path)

    def set_favorite(self):
        with Session(engine) as db:
            updated = update_sample(
                db,
                path=Path(self.sample.path),
                input=SampleUpdateInput(is_favorite=(not self.sample.is_favorite)),
            )
            if updated is None:
                return
            self.favorite_set.emit(updated)

    def find_similar(self):
        sample = self.store._state.selected_sample
        if sample is None:
            return

        with Session(engine) as db:
            data = get_similar_samples(
                db,
                Path(sample.path),
                input=SampleSimilarInput(
                    name=self.store._state.search_key,
                    byWidth=self.store._state.filters.by_width,
                    byFreq=self.store._state.filters.by_freq,
                ),
            )
            self.store.set_state("results", data)
