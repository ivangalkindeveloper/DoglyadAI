from __future__ import annotations

import contextlib
import io
import stat
import tempfile
import unittest
from pathlib import Path

from tools.format_python import PythonFormatter


class PythonFormattingTests(unittest.TestCase):
    def setUp(
        self,
    ) -> None:
        self.formatter = PythonFormatter()
        self.filename = PythonFormatter.BACKEND / "main" / "formatter_example.py"

    def format(
        self,
        source: str,
    ) -> str:
        return self.formatter.format_source(
            source,
            self.filename,
        )

    def test_single_and_nested_constructor_arguments(
        self,
    ) -> None:
        self.assertEqual(
            self.format(
                "result = Client(config, timeout=seconds(30))\n",
            ),
            "result = Client(\n    config,\n    timeout=seconds(\n        30,\n    ),\n)\n",
        )

    def test_function_and_constructor_parameters(
        self,
    ) -> None:
        result = self.format(
            "class Client:\n"
            "    def __init__(self, token: str): self.token = token\n"
            "    async def load(self, path, /, *items, timeout=30, **options): pass\n"
            "def positional(value, /): pass\n"
            "def keyword(*, value): pass\n"
            "def variadic(*items): pass\n",
        )
        self.assertIn(
            "def __init__(\n        self,\n        token: str,\n    ):",
            result,
        )
        self.assertIn(
            "async def load(\n        self,\n        path,\n        /,\n        *items,\n"
            "        timeout=30,\n        **options,\n    ):",
            result,
        )
        self.assertIn(
            "def positional(\n    value,\n    /,\n):",
            result,
        )
        self.assertIn(
            "def keyword(\n    *,\n    value,\n):",
            result,
        )
        self.assertIn(
            "def variadic(\n    *items,\n):",
            result,
        )

    def test_decorators_annotations_and_defaults(
        self,
    ) -> None:
        result = self.format(
            '@route("/pay", methods=["POST"])\n'
            "def pay(owner: Annotated[str, Header(alias='X-Owner')], key=Depends(get_key)): pass\n",
        )
        self.assertIn(
            '@route(\n    "/pay",\n    methods=["POST"],\n)',
            result,
        )
        self.assertIn(
            'Header(\n            alias="X-Owner",\n        )',
            result,
        )
        self.assertIn(
            "key=Depends(\n        get_key,\n    ),",
            result,
        )

    def test_implicit_generators_remain_generators(
        self,
    ) -> None:
        result = self.format(
            "result = list(convert(item) for item in items)\n",
        )
        namespace = {"items": [1, 2], "convert": lambda item: item * 2}
        exec(
            result,
            namespace,
        )
        self.assertEqual(
            namespace["result"],
            [2, 4],
        )
        self.assertIn(
            "list(\n",
            result,
        )
        self.assertIn(
            "convert(\n",
            result,
        )

    def test_comments_and_type_ignores_are_preserved(
        self,
    ) -> None:
        source = (
            "# heading\n"
            "result = call(first,  # first value\n"
            "              second  # last value\n"
            ")  # type: ignore[call-arg]\n"
        )
        result = self.format(
            source,
        )
        for comment in (
            "# heading",
            "# first value",
            "# last value",
            "# type: ignore[call-arg]",
        ):
            self.assertEqual(
                result.count(
                    comment,
                ),
                1,
            )
        self.assertIn(
            "second,  # last value",
            result,
        )
        self.assertIn(
            ")  # type: ignore[call-arg]",
            result,
        )

    def test_string_values_and_f_string_expressions_are_preserved(
        self,
    ) -> None:
        source = (
            '"""call(a, b)\nOriginal docstring content.\n"""\n'
            'pattern = r"call\\(a, b\\)"\n'
            'text = f"value: {call(1, 2)!r}"\n'
            'multiline = f"""{call(1, 2)}\nnext line"""\n'
            "send(text, pattern)\n"
        )
        result = self.format(
            source,
        )
        self.assertIn(
            'f"value: {call(1, 2)!r}"',
            result,
        )
        self.assertIn(
            'f"""{call(1, 2)}\nnext line"""',
            result,
        )
        namespace = {"call": lambda *args: args, "send": lambda *args: None}
        exec(
            source,
            namespace,
        )
        expected = {
            key: namespace[key] for key in ("__doc__", "pattern", "text", "multiline")
        }
        exec(
            result,
            namespace,
        )
        self.assertEqual(
            {key: namespace[key] for key in expected},
            expected,
        )

    def test_semantic_docstring_rewrites_are_rejected(
        self,
    ) -> None:
        # Ruff normalizes this indentation, changing the actual string value.
        with self.assertRaisesRegex(
            ValueError,
            "change Python semantics",
        ):
            self.format(
                '"""Summary.\n    Significant indentation.\n"""\n',
            )

    def test_lambda_parameters_inheritance_and_subscripts(
        self,
    ) -> None:
        result = self.format(
            "class Client(Base, metaclass=Meta): pass\n"
            "convert = lambda left, right: call(left, right)\n"
            "value = items[key]\n",
        )
        self.assertIn(
            "class Client(Base, metaclass=Meta):",
            result,
        )
        self.assertIn(
            "lambda left, right: call(\n",
            result,
        )
        self.assertIn(
            "items[key]",
            result,
        )

    def test_empty_lists_stay_empty(
        self,
    ) -> None:
        result = self.format(
            "def empty():\n    return call()\n",
        )
        self.assertIn(
            "def empty():",
            result,
        )
        self.assertIn(
            "call()",
            result,
        )

    def test_pipeline_is_idempotent(
        self,
    ) -> None:
        source = "@cache(size=10)\ndef call(value, /, *, default=make(1)):\n    return use(value, default)\n"
        formatted = self.format(
            source,
        )
        self.assertEqual(
            self.format(
                formatted,
            ),
            formatted,
        )

    def test_check_does_not_write_and_apply_preserves_executable_mode(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = (
                Path(
                    directory,
                )
                / "script.py"
            )
            original = "#!/usr/bin/env python3\nprint(1, 2)\n"
            path.write_text(
                original,
            )
            path.chmod(
                0o755,
            )
            with (
                contextlib.redirect_stdout(
                    io.StringIO(),
                ),
                contextlib.redirect_stderr(
                    io.StringIO(),
                ),
            ):
                self.assertEqual(
                    self.formatter.format_paths(
                        [path],
                        is_check=True,
                    ),
                    1,
                )
                self.assertEqual(
                    path.read_text(),
                    original,
                )
                self.assertEqual(
                    self.formatter.format_paths(
                        [path],
                        is_check=False,
                    ),
                    0,
                )
                self.assertEqual(
                    self.formatter.format_paths(
                        [path],
                        is_check=True,
                    ),
                    0,
                )
            self.assertNotEqual(
                path.read_text(),
                original,
            )
            self.assertEqual(
                stat.S_IMODE(
                    path.stat().st_mode,
                ),
                0o755,
            )
            self.assertEqual(
                list(
                    path.parent.iterdir(),
                ),
                [path],
            )

    def test_parse_failure_prevents_partial_batch_changes(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = (
                Path(
                    directory,
                )
                / "a.py"
            )
            invalid = (
                Path(
                    directory,
                )
                / "b.py"
            )
            original = "call(1, 2)\n"
            first.write_text(
                original,
            )
            invalid.write_text(
                "def broken(\n",
            )
            with self.assertRaises(
                SyntaxError,
            ):
                self.formatter.format_paths(
                    [
                        Path(
                            directory,
                        )
                    ],
                    is_check=False,
                )
            self.assertEqual(
                first.read_text(),
                original,
            )

    def test_secrets_virtual_environments_and_symlinks_are_excluded(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(
                directory,
            )
            for folder in ("secrets", ".venv", "__pycache__"):
                (root / folder).mkdir()
                (root / folder / "invalid.py").write_text(
                    "invalid python!",
                )
            target = root / "module.py"
            target.write_text(
                "call(1)\n",
            )
            (root / "linked.py").symlink_to(
                target,
            )
            (root / "linked_directory").symlink_to(
                root / "secrets",
                target_is_directory=True,
            )
            self.assertEqual(
                self.formatter._files(
                    [root, target],
                ),
                [target],
            )


if __name__ == "__main__":
    unittest.main()
