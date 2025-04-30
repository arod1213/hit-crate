from app.backend.db import engine
from app.backend.schemas import SampleQueryInput
from app.backend.services import SampleService
from app.frontend.store import Store, StoreState
from sqlmodel import Session


class SearchAllTrigger:
    def __init__(self):
        self.store = Store()

        self.store.subscribe("search_key", self.trigger_search)
        self.store.subscribe("filters", self.trigger_search)

    def trigger_search(self, state: StoreState):
        with Session(engine) as db_session:
            data = SampleService(db_session).query_samples(
                SampleQueryInput(
                    name=state.search_key,
                    spectral_centroid=self.store._state.filters.spectral_centroid,
                )
            )
        self.store.set_state("results", data)
