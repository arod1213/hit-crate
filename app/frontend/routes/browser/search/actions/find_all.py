from app.backend.db import engine
from app.backend.schemas import SampleQueryInput
from app.backend.services import SampleService
from app.frontend.store import Store, StoreState
from sqlmodel import Session


class SearchAllTrigger:
    def __init__(self):
        self.store = Store()

        self.store.subscribe("search_key", self.trigger_search)
        self.store.subscribe("curr_path", self.trigger_search)
        self.store.subscribe("spectral_centroid", self.trigger_search)
        self.store.subscribe("stereo_width", self.trigger_search)
        self.store.subscribe("by_favorites", self.trigger_search)

    def trigger_search(self, state: StoreState):
        with Session(engine) as db_session:
            data = SampleService(db_session).query_samples(
                SampleQueryInput(
                    name=state.search_key,
                    spectral_centroid=self.store._state.spectral_centroid,
                    width=self.store._state.stereo_width,
                    is_favorite=self.store._state.by_favorites,
                    path=self.store._state.curr_path,
                )
            )
        self.store.set_state("results", data)
