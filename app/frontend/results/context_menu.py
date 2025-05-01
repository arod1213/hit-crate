from pathlib import Path

from PyQt6.QtCore import pyqtSignal
from PyQt6.QtGui import QAction
from PyQt6.QtWidgets import QMenu
from sqlmodel import Session

from app.backend.db import engine
from app.backend.models import Sample
from app.backend.services.sample_service import SampleService


class ContextMenu(QMenu):
    favorite_set = pyqtSignal(object)

    def __init__(self, sample: Sample):
        super().__init__()

        self.sample = sample

        fav_action = QAction("Favorite", self)
        fav_action.triggered.connect(self.set_favorite)
        self.addAction(fav_action)

    def set_favorite(self):
        with Session(engine) as session:
            updated_sample = SampleService(session).update(
                path=Path(self.sample.path),
                is_favorite=(not self.sample.is_favorite),
            )
            if updated_sample is not None:
                self.favorite_set.emit(updated_sample)
