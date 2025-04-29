import os

from dotenv import load_dotenv
from sqlmodel import SQLModel, create_engine

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")

# Create an engine
engine = create_engine(DATABASE_URL, echo=True)


# Function to create tables
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)


# Initialize the database (run this when setting up or after changing models)
if __name__ == "__main__":
    create_db_and_tables()
