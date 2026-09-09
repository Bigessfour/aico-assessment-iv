"""Import helpers for the service tests.

All four services ship a module literally named ``app.py``, so a plain import
would collide. Each test loads the file it needs under a unique alias, which
also means every test gets a fresh module with fresh env-derived constants and
fresh gateway counters.
"""

from __future__ import annotations

import importlib.util
import pathlib
import sys

SERVICES = pathlib.Path(__file__).resolve().parents[1] / "services"


def load_service(alias: str, relative_path: str):
    """Load services/<relative_path> as a module named <alias>."""
    path = SERVICES / relative_path
    spec = importlib.util.spec_from_file_location(alias, path)
    if spec is None or spec.loader is None:  # pragma: no cover - import plumbing
        raise ImportError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[alias] = module
    spec.loader.exec_module(module)
    return module
