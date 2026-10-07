import os
import tempfile

# Point the app at a throwaway SQLite file *before* app.config is imported,
# so tests never touch the real PostgreSQL database.
_db_dir = tempfile.mkdtemp(prefix="taskboard-test-")
os.environ["DATABASE_URL"] = f"sqlite:///{_db_dir}/test.db"

import pytest
from app.db import Base, engine


@pytest.fixture(scope="session", autouse=True)
def database():
    # TestClient(app) without a `with` block never fires FastAPI's startup
    # event, so the schema has to be created here instead.
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
