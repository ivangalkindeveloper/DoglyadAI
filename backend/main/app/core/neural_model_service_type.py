from __future__ import annotations

from enum import StrEnum


class NeuralModelServiceType(StrEnum):
    INFERENCE = "inference"
    MOCK = "mock"
