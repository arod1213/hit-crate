from typing import Optional

from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QPushButton
from sqlmodel import Session
from pathlib import Path

from app.backend.models import Sample
from app.backend.db import engine
from app.backend.services.sample_service import SampleService
from app.frontend.store import Store, StoreState


class FavoriteButton(QPushButton):
    def __init__(self, sample: Sample):
        super().__init__()
        self.sample = sample

        self.setStyleSheet("""
            QPushButton {
                border: none;
                background: transparent;
            }
            QPushButton:checked {
                /* Optional: tint or style for active state */
                color: #e31b23;
            }
        """)

        self.setCheckable(True)
        self.setChecked(sample.is_favorite)
        self.setIcon(QIcon('app/frontend/assets/heart-icon.svg'))
        self.setIconSize(self.sizeHint())

        self.setFixedSize(20, 20)

        self.toggled.connect(self.toggle_favorite)  # 🔁 connect signal

    def toggle_favorite(self):
        value = not self.sample.is_favorite
        print(f"VALUE IS {value}", self.sample.is_favorite)
        with Session(engine) as session:
            SampleService(session).update(Path(self.sample.path), value)
        self.setChecked(value)
