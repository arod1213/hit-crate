import os
from pathlib import Path

from dotenv import load_dotenv
from sqlmodel import create_engine, inspect, text

from app.backend.models import Base

APP_NAME = "HitCrate"


def get_default_db_path() -> Path:
    support_dir = Path.home() / "Library" / "Application Support" / APP_NAME
    support_dir.mkdir(parents=True, exist_ok=True)
    return support_dir / "hitcrate.db"


load_dotenv()
# env_db_url = os.getenv("DATABASE_URL")
#
# if env_db_url:
#     DATABASE_URL = env_db_url
# else:
#     db_path = get_default_db_path()
#     DATABASE_URL = f"sqlite:///{db_path}"

db_path = get_default_db_path()
DATABASE_URL = f"sqlite:///{str(db_path)}"
engine = create_engine(DATABASE_URL, echo=False)


def migrate_database():
    """Handle schema migrations for existing user databases"""
    inspector = inspect(engine)

    if "sample" in inspector.get_table_names():
        columns = [col["name"] for col in inspector.get_columns("sample")]
        sample_indexes = {index["name"] for index in inspector.get_indexes("sample")}

        with engine.begin() as conn:
            if "rolloff" not in columns:
                print("Adding rolloff column to sample table")
                conn.execute(text("ALTER TABLE sample ADD COLUMN rolloff FLOAT"))

            if "ix_sample_parent_path" not in sample_indexes:
                conn.execute(
                    text(
                        "CREATE INDEX IF NOT EXISTS ix_sample_parent_path "
                        "ON sample (parent_path)"
                    )
                )

            if "ix_sample_is_favorite" not in sample_indexes:
                conn.execute(
                    text(
                        "CREATE INDEX IF NOT EXISTS ix_sample_is_favorite "
                        "ON sample (is_favorite)"
                    )
                )

            if "ix_sample_parent_path_is_favorite" not in sample_indexes:
                conn.execute(
                    text(
                        "CREATE INDEX IF NOT EXISTS ix_sample_parent_path_is_favorite "
                        "ON sample (parent_path, is_favorite)"
                    )
                )

            if "ix_sample_stereo_width" not in sample_indexes:
                conn.execute(
                    text(
                        "CREATE INDEX IF NOT EXISTS ix_sample_stereo_width "
                        "ON sample (stereo_width)"
                    )
                )

            if "ix_sample_spectral_centroid" not in sample_indexes:
                conn.execute(
                    text(
                        "CREATE INDEX IF NOT EXISTS ix_sample_spectral_centroid "
                        "ON sample (spectral_centroid)"
                    )
                )

            if "ix_sample_rolloff" not in sample_indexes:
                conn.execute(
                    text(
                        "CREATE INDEX IF NOT EXISTS ix_sample_rolloff "
                        "ON sample (rolloff)"
                    )
                )


def create_db_and_tables():
    Base.metadata.create_all(engine)
    migrate_database()


if __name__ == "__main__":
    create_db_and_tables()
