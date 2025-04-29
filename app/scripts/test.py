from pathlib import Path

from app.data.db import engine
from app.data.scanner import import_samples_from_folder
from sqlmodel import Session


def main():
    test_folder = Path.home() / "Desktop" / "Scan Test"
    with Session(engine) as session:
        import_samples_from_folder(test_folder, session)
    print("Import completed.")


if __name__ == "__main__":
    main()
