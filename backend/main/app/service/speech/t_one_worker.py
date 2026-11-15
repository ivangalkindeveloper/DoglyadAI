from __future__ import annotations

import hashlib
from pathlib import Path
from typing import TYPE_CHECKING, ClassVar

if TYPE_CHECKING:
    from tone import StreamingCTCPipeline


class TOneWorker:
    """One pipeline in the dedicated CPU process, never in the HTTP event loop."""

    revision: ClassVar[str] = "106f3b0b32a9e107eb613312e4ebc61ff3d53926"
    checksums: ClassVar[dict[str, str]] = {
        "model.onnx": "707e4a282d5036304a0b8603ad83945840c3075f53c49911ef88c19bcc5a7d52",
        "kenlm.bin": "8c31a489a51a6e9236112dacb6bed12f45e8df734057615fa6bf220a5a769a1d",
    }
    _pipeline: ClassVar[StreamingCTCPipeline | None] = None

    def __init__(
        self,
    ) -> None:
        pass

    @classmethod
    def initialize(
        cls,
        model_path: Path,
        cpu_threads: int,
    ) -> None:
        import onnxruntime as ort
        from tone import BeamSearchCTCDecoder, StreamingCTCModel, StreamingCTCPipeline, StreamingLogprobSplitter

        for filename, checksum in cls.checksums.items():
            with (model_path / filename).open(
                "rb",
            ) as source:
                if (
                    hashlib.file_digest(
                        source,
                        "sha256",
                    ).hexdigest()
                    != checksum
                ):
                    raise RuntimeError(
                        "T-one model checksum mismatch",
                    )
        ort.disable_telemetry_events()
        options = ort.SessionOptions()
        options.intra_op_num_threads = cpu_threads
        options.inter_op_num_threads = 1
        session = ort.InferenceSession(
            str(
                model_path / "model.onnx",
            ),
            sess_options=options,
            providers=["CPUExecutionProvider"],
        )
        cls._pipeline = StreamingCTCPipeline(
            StreamingCTCModel(
                session,
            ),
            StreamingLogprobSplitter(),
            BeamSearchCTCDecoder.from_local(
                model_path / "kenlm.bin",
            ),
        )

    @classmethod
    def transcribe(
        cls,
        audio: bytes,
    ) -> str:
        import numpy as np

        if cls._pipeline is None:
            raise RuntimeError(
                "T-one worker is not initialized",
            )
        # The public transport is headerless mono PCM16 little-endian at 8 kHz.
        samples = np.frombuffer(
            audio,
            dtype="<i2",
        ).astype(
            np.int32,
        )
        phrases = cls._pipeline.forward_offline(
            samples,
        )
        return " ".join(
            (phrase.text.strip() for phrase in phrases if phrase.text.strip()),
        )
