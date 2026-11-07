"""Validated, non-secret configuration for one inference host (stdlib only)."""

from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any


class HostProfile:
    data: dict[str, Any]
    server_config: dict[str, Any]

    def __init__(self, data: dict[str, Any], server_config: dict[str, Any]) -> None:
        self.data = data
        self.server_config = server_config
        self._validate()

    @property
    def architecture(self) -> str:
        return self.data["architecture"]

    @property
    def models(self) -> dict[str, str]:
        return {model["modelId"]: model["service"] for model in self.data["models"]}

    @property
    def endpoints(self) -> dict[str, str]:
        return {
            model: f"http://{service}:8000" for model, service in self.models.items()
        }

    @property
    def fingerprint(self) -> str:
        content = dict(self.data, serverConfig=self.server_config)
        return hashlib.sha256(json.dumps(content, sort_keys=True).encode()).hexdigest()

    @classmethod
    def load(cls, path: Path) -> HostProfile:
        data = json.loads(path.read_text(), object_pairs_hook=cls._unique_keys)
        if not isinstance(data, dict) or not isinstance(data.get("serverConfig"), str):
            raise ValueError("Profile requires a serverConfig JSON path")
        config = json.loads(
            (path.parent / data["serverConfig"]).read_text(),
            object_pairs_hook=cls._unique_keys,
        )
        return cls(data, config)

    @staticmethod
    def _unique_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate JSON key")
            result[key] = value
        return result

    @staticmethod
    def _keys(value: Any, required: set[str], optional: set[str] | None = None) -> None:
        if not isinstance(value, dict):
            raise ValueError("Expected a JSON object")
        if not required <= value.keys() or value.keys() - required - (
            optional or set()
        ):
            raise ValueError("Missing or unknown profile fields")

    @staticmethod
    def _integer(value: Any, minimum: int = 1) -> None:
        if type(value) is not int or value < minimum:
            raise ValueError("Expected a positive integer profile setting")

    @staticmethod
    def _name(value: Any) -> None:
        if not isinstance(value, str) or not re.fullmatch(r"[a-z][a-z0-9_-]*", value):
            raise ValueError("Invalid Compose name")

    @staticmethod
    def _image(value: Any) -> None:
        if not isinstance(value, str) or not re.fullmatch(
            r"[A-Za-z0-9][A-Za-z0-9./:_-]*@sha256:[0-9a-f]{64}", value
        ):
            raise ValueError("vLLM images must be pinned by digest")

    def _validate(self) -> None:
        self._keys(
            self.data,
            {
                "version",
                "projectName",
                "architecture",
                "vllmImage",
                "weightsVolume",
                "serverConfig",
                "models",
            },
        )
        if type(self.data["version"]) is not int or self.data["version"] != 1:
            raise ValueError("Unsupported host profile version")
        if self.architecture not in {"amd64", "arm64"}:
            raise ValueError("Unsupported host architecture")
        self._name(self.data["projectName"])
        self._image(self.data["vllmImage"])
        volume = self.data["weightsVolume"]
        self._keys(volume, {"name", "isExternal"})
        self._name(volume["name"])
        if type(volume["isExternal"]) is not bool:
            raise ValueError("isExternal must be boolean")
        if not isinstance(self.server_config, dict):
            raise ValueError("serverConfig must contain a JSON object")
        models = self.data["models"]
        if not isinstance(models, list) or not models:
            raise ValueError("A host must contain at least one model")
        ids: set[str] = set()
        services: set[str] = {"backend_inference", "model_download"}
        for model in models:
            self._keys(
                model,
                {
                    "modelId",
                    "service",
                    "dtype",
                    "maxModelLen",
                    "maxNumSeqs",
                    "maxNumBatchedTokens",
                    "gpuMemoryUtilization",
                    "gpuDeviceIds",
                    "tensorParallelSize",
                    "isEager",
                    "isPrefixCachingEnabled",
                },
                {
                    "image",
                    "maxImages",
                    "kvCacheMemoryBytes",
                    "revision",
                    "speculativeConfig",
                },
            )
            model_id = model["modelId"]
            if (
                not isinstance(model_id, str)
                or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", model_id)
                or model_id in ids
            ):
                raise ValueError("Model IDs must be valid and unique within a host")
            ids.add(model_id)
            service = model["service"]
            self._name(service)
            if service in services:
                raise ValueError("Model service names must be unique and unreserved")
            services.add(service)
            if "image" in model:
                self._image(model["image"])
            if model["dtype"] not in {"auto", "bfloat16", "float16", "float32"}:
                raise ValueError("Unsupported model dtype")
            for key in (
                "maxModelLen",
                "maxNumSeqs",
                "maxNumBatchedTokens",
                "tensorParallelSize",
            ):
                self._integer(model[key])
            for key in ("maxImages", "kvCacheMemoryBytes"):
                if key in model:
                    self._integer(model[key], 0 if key == "maxImages" else 1)
            fraction = model["gpuMemoryUtilization"]
            if (
                type(fraction) not in {int, float}
                or not math.isfinite(fraction)
                or not 0 < fraction <= 1
            ):
                raise ValueError("GPU memory utilization must be in (0, 1]")
            for key in ("isEager", "isPrefixCachingEnabled"):
                if type(model[key]) is not bool:
                    raise ValueError("Model flags must be boolean")
            devices = model["gpuDeviceIds"]
            if (
                not isinstance(devices, list)
                or not devices
                or any(
                    not isinstance(device, str) or not re.fullmatch(r"[0-9]+", device)
                    for device in devices
                )
                or len(set(devices)) != len(devices)
            ):
                raise ValueError("gpuDeviceIds must contain unique numeric device IDs")
            if model["tensorParallelSize"] != len(devices):
                raise ValueError("tensorParallelSize must match gpuDeviceIds")
            if "revision" in model and (
                not isinstance(model["revision"], str)
                or not re.fullmatch(r"[0-9a-f]{40}", model["revision"])
            ):
                raise ValueError("Model revision must be a full commit SHA")
            if "speculativeConfig" in model:
                self._validate_speculation(model["speculativeConfig"])

    def _validate_speculation(self, config: Any) -> None:
        self._keys(
            config,
            {"method", "numSpeculativeTokens", "promptLookupMin", "promptLookupMax"},
        )
        if config["method"] != "ngram":
            raise ValueError("Only ngram speculative decoding is supported")
        for key in ("numSpeculativeTokens", "promptLookupMin", "promptLookupMax"):
            self._integer(config[key])
        if config["promptLookupMin"] > config["promptLookupMax"]:
            raise ValueError("promptLookupMin must not exceed promptLookupMax")
