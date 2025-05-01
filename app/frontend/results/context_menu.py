from pathlib import Path

from PyQt6.QtCore import pyqtSignal
from PyQt6.QtGui import QAction
from PyQt6.QtWidgets import QMenu
from sqlmodel import Session

from app.backend.db import engine
from app.backend.models import Sample
from app.backend.schemas import SampleSimilarInput
from app.backend.services.sample_service import SampleService
from app.frontend.store import Store


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

    def set_favorite(self):
        with Session(engine) as session:
            updated_sample = SampleService(session).update(
                path=Path(self.sample.path),
                is_favorite=(not self.sample.is_favorite),
            )
            if updated_sample is not None:
                self.favorite_set.emit(updated_sample)

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
