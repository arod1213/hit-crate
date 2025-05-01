import os
from dotenv import load_dotenv
from sqlmodel import SQLModel, create_engine
from pathlib import Path
from app.backend.models import Base, Sample, Directory

APP_NAME = "HitCrate"

def get_default_db_path():
    support_dir = Path.home() / "Library" / "Application Support" / APP_NAME
    support_dir.mkdir(parents=True, exist_ok=True)
    return support_dir / "hitcrate.db"

load_dotenv()
env_db_url = os.getenv("DATABASE_URL")

if env_db_url:
    DATABASE_URL = env_db_url
else:
    db_path = get_default_db_path()
    DATABASE_URL = f"sqlite:///{db_path}"

engine = create_engine(DATABASE_URL, echo=True)

def create_db_and_tables():
    print("Creating tables...")
    Base.metadata.create_all(engine)
    print(f"✅ Database schema created at {DATABASE_URL}")


if __name__ == "__main__":
    create_db_and_tables()