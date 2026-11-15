from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from huggingface_hub import hf_hub_download

from app.service.speech.t_one_worker import TOneWorker


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download the pinned T-one acoustic and KenLM models",
    )
    parser.add_argument(
        "directory",
        type=Path,
    )
    directory: Path = parser.parse_args().directory
    directory.mkdir(
        parents=True,
        exist_ok=True,
    )
    for filename, checksum in TOneWorker.checksums.items():
        path = hf_hub_download(
            "t-tech/T-one",
            filename,
            revision=TOneWorker.revision,
            local_dir=directory,
        )
        with Path(
            path,
        ).open(
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


if __name__ == "__main__":
    main()
