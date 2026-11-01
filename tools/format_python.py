from __future__ import annotations

import argparse
import ast
import io
import os
import stat
import subprocess
import sys
import tempfile
import tokenize
from pathlib import Path

import libcst as cst

if __package__:
    from .python_argument_transformer import PythonArgumentTransformer
else:
    from python_argument_transformer import PythonArgumentTransformer


class PythonFormatter:
    ROOT = (
        Path(
            __file__,
        )
        .resolve()
        .parents[1]
    )
    BACKEND = ROOT / "backend"
    EXCLUDED = frozenset(
        {
            "secrets",
            ".git",
            ".venv",
            ".venv311",
            "venv",
            "__pycache__",
            "build",
            "dist",
        },
    )

    def __init__(
        self,
        ruff: list[str] | None = None,
    ) -> None:
        self._ruff = ruff if ruff is not None else [sys.executable, "-m", "ruff"]

    def format_source(
        self,
        source: str,
        filename: Path,
    ) -> str:
        before = ast.parse(
            source,
            filename=str(
                filename,
            ),
            feature_version=(3, 11),
        )
        rewritten = (
            cst.parse_module(
                source,
            )
            .visit(
                PythonArgumentTransformer(),
            )
            .code
        )
        result = subprocess.run(
            [
                *self._ruff,
                "format",
                "--quiet",
                "--stdin-filename",
                str(
                    filename,
                ),
                "-",
            ],
            input=rewritten,
            text=True,
            capture_output=True,
            check=True,
        )
        formatted = result.stdout
        after = ast.parse(
            formatted,
            filename=str(
                filename,
            ),
            feature_version=(3, 11),
        )
        if ast.dump(
            before,
            include_attributes=False,
        ) != ast.dump(
            after,
            include_attributes=False,
        ):
            raise ValueError(
                f"Formatting would change Python semantics: {filename}",
            )
        if self._comments(
            source,
        ) != self._comments(
            formatted,
        ):
            raise ValueError(
                f"Formatting would change Python comments: {filename}",
            )
        self._validate_layout(
            after,
            filename,
        )
        return formatted

    def format_paths(
        self,
        paths: list[Path],
        *,
        is_check: bool,
    ) -> int:
        # Validate every result before changing any file.
        updates: list[tuple[Path, bytes]] = []
        files = self._files(
            paths,
        )
        for path in files:
            original = path.read_bytes()
            encoding, _ = tokenize.detect_encoding(
                io.BytesIO(
                    original,
                ).readline,
            )
            formatted = self.format_source(
                original.decode(
                    encoding,
                ),
                path,
            ).encode(
                encoding,
            )
            if formatted != original:
                updates.append(
                    (path, formatted),
                )
        if is_check:
            for path, _ in updates:
                print(
                    f"Needs Python argument formatting: {path}",
                    file=sys.stderr,
                )
        else:
            for path, formatted in updates:
                self._replace(
                    path,
                    formatted,
                )
        print(
            f"Python formatting: {len(updates)}/{len(files)} files {'need changes' if is_check else 'formatted'}.",
        )
        return 1 if is_check and updates else 0

    @classmethod
    def _files(
        cls,
        paths: list[Path],
    ) -> list[Path]:
        files: set[Path] = set()
        for source in paths:
            path = source.absolute()
            if path.is_symlink() or any(
                (part in cls.EXCLUDED for part in path.parts),
            ):
                continue
            if path.is_file():
                if path.suffix == ".py":
                    files.add(
                        path,
                    )
            elif path.is_dir():
                for directory, children, names in os.walk(
                    path,
                    followlinks=False,
                ):
                    children[:] = sorted(
                        (
                            name
                            for name in children
                            if name not in cls.EXCLUDED
                            and not name.startswith(
                                ".",
                            )
                        ),
                    )
                    for name in names:
                        candidate = (
                            Path(
                                directory,
                            )
                            / name
                        )
                        if candidate.suffix == ".py" and not candidate.is_symlink():
                            files.add(
                                candidate,
                            )
            else:
                raise ValueError(
                    f"Python formatting path does not exist: {source}",
                )
        return sorted(
            files,
        )

    @staticmethod
    def _replace(
        path: Path,
        content: bytes,
    ) -> None:
        temporary: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                dir=path.parent,
                prefix=f".{path.name}.",
                delete=False,
            ) as output:
                temporary = Path(
                    output.name,
                )
                output.write(
                    content,
                )
            temporary.chmod(
                stat.S_IMODE(
                    path.stat().st_mode,
                ),
            )
            os.replace(
                temporary,
                path,
            )
        finally:
            if temporary is not None:
                temporary.unlink(
                    missing_ok=True,
                )

    @staticmethod
    def _comments(
        source: str,
    ) -> list[str]:
        return [
            token.string
            for token in tokenize.generate_tokens(
                io.StringIO(
                    source,
                ).readline,
            )
            if token.type == tokenize.COMMENT
        ]

    @classmethod
    def _validate_layout(
        cls,
        node: ast.AST,
        filename: Path,
    ) -> None:
        if isinstance(
            node,
            ast.JoinedStr,
        ):
            return
        if isinstance(
            node,
            ast.Call,
        ):
            arguments = sorted(
                [*node.args, *node.keywords],
                key=lambda value: (value.lineno, value.col_offset),
            )
            previous_line = node.func.end_lineno or node.func.lineno
            for argument in arguments:
                if argument.lineno <= previous_line:
                    raise ValueError(
                        f"Call argument is not on its own line: {filename}:{argument.lineno}",
                    )
                previous_line = argument.end_lineno or argument.lineno
            if arguments and (node.end_lineno or node.lineno) <= previous_line:
                raise ValueError(
                    f"Call closing parenthesis is not on its own line: {filename}:{node.lineno}",
                )
        elif isinstance(
            node,
            (ast.FunctionDef, ast.AsyncFunctionDef),
        ):
            parameters = [*node.args.posonlyargs, *node.args.args]
            if node.args.vararg is not None:
                parameters.append(
                    node.args.vararg,
                )
            parameters.extend(
                node.args.kwonlyargs,
            )
            if node.args.kwarg is not None:
                parameters.append(
                    node.args.kwarg,
                )
            previous_line = node.lineno
            for parameter in parameters:
                if parameter.lineno <= previous_line:
                    raise ValueError(
                        f"Function parameter is not on its own line: {filename}:{parameter.lineno}",
                    )
                previous_line = parameter.lineno
        for child in ast.iter_child_nodes(
            node,
        ):
            cls._validate_layout(
                child,
                filename,
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Format Python call arguments and function parameters on separate lines.",
    )
    parser.add_argument(
        "--check",
        dest="is_check",
        action="store_true",
        help="Check without modifying files.",
    )
    parser.add_argument(
        "--ruff",
        help="Path to the Ruff executable (defaults to this Python's ruff module).",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="Files/directories; defaults to backend/.",
    )
    arguments = parser.parse_args()
    formatter = PythonFormatter(
        [arguments.ruff] if arguments.ruff else None,
    )
    try:
        sys.exit(
            formatter.format_paths(
                arguments.paths or [PythonFormatter.BACKEND],
                is_check=arguments.is_check,
            ),
        )
    except subprocess.CalledProcessError as error:
        print(
            error.stderr
            or str(
                error,
            ),
            file=sys.stderr,
        )
        sys.exit(
            2,
        )
    except (OSError, ValueError, SyntaxError, cst.ParserSyntaxError) as error:
        print(
            str(
                error,
            ),
            file=sys.stderr,
        )
        sys.exit(
            2,
        )
