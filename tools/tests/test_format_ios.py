from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.format_ios import IOS, argument_formatter, swift_files


class ArgumentFormattingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.executable = argument_formatter()

    def format(self, source: str) -> str:
        rewritten = subprocess.check_output(
            [str(self.executable), "--stdin"], input=source, text=True
        )
        return subprocess.check_output(
            ["swiftformat", "stdin", "--config", str(IOS / ".swiftformat"), "--quiet"],
            input=rewritten,
            text=True,
        )

    def test_short_single_and_nested_calls(self) -> None:
        result = self.format('fill(name: "Ivan", weight: scalar(value: 82))\n')
        self.assertEqual(
            result,
            'fill(\n    name: "Ivan",\n    weight: scalar(\n        value: 82,\n    ),\n)\n',
        )

    def test_parameters_and_comment_ownership(self) -> None:
        result = self.format(
            "func fill(name: String, weight: Int) { print(name, weight) }\n"
            'fill(name: "Ivan", // patient name\n'
            "weight: 82 /* body weight */)\n"
        )
        self.assertIn("name: String,\n    weight: Int,\n)", result)
        self.assertIn('name: "Ivan", // patient name', result)
        self.assertIn("weight: 82, /* body weight */", result)
        self.assertEqual(result.count("// patient name"), 1)
        self.assertEqual(result.count("/* body weight */"), 1)

    def test_literals_and_interpolation_are_preserved(self) -> None:
        source = r"""let text = "weight: \(scalar(value: 82))"
let raw = #"fill(a: 1, b: 2)"#
let pattern = #/foo\(a, b\)/#
print(text, raw, pattern)
"""
        result = self.format(source)
        for line in source.splitlines()[:3]:
            self.assertIn(line, result)
        self.assertIn("print(\n    text,\n    raw,\n    pattern,\n)", result)

    def test_multiline_literal_interpolation_is_preserved(self) -> None:
        source = 'let text = """\n    weight: \\(scalar(value: 82))\n    """\n'
        result = self.format(source)
        self.assertIn("weight: \\(scalar(value: 82))", result)

    def test_macros_attributes_and_subscripts(self) -> None:
        result = self.format(
            '@Test("case") func sample() { #expect(values[0] == 82) }\n'
        )
        self.assertIn('@Test(\n    "case",\n)', result)
        self.assertIn("#expect(\n", result)
        self.assertIn("values[\n", result)
        self.assertIn("0,\n", result)

    def test_empty_calls_and_function_types(self) -> None:
        result = self.format(
            "let callback: (Int, String) -> Void = { _, _ in }\nempty()\n"
        )
        self.assertIn("empty()", result)
        self.assertIn("(Int, String) -> Void", result)

    def test_result_is_stable(self) -> None:
        first = self.format('fill(name: "Ivan", weight: scalar(value: 82))\n')
        self.assertEqual(self.format(first), first)

    def test_compiles_with_project_language_mode(self) -> None:
        source = """func scalar(value: Int) -> Int { value }
func fill(name: String, weight: Int) { print(name, weight) }
func run() {
    fill(name: "Ivan", weight: scalar(value: 82))
    let text = "weight: \\(scalar(value: 82))"
    let values = [82]
    print(values[0], text)
}
"""
        result = self.format(source)
        sdk = subprocess.check_output(
            ["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True
        ).strip()
        with tempfile.TemporaryDirectory(prefix="doglyad-format-test-") as directory:
            path = Path(directory) / "Example.swift"
            path.write_text(result)
            subprocess.run(
                [
                    "xcrun",
                    "swiftc",
                    "-sdk",
                    sdk,
                    "-swift-version",
                    "5",
                    "-typecheck",
                    str(path),
                ],
                check=True,
                capture_output=True,
                text=True,
            )

    def test_protected_files_are_excluded(self) -> None:
        for path in swift_files():
            self.assertNotIn("/ios/Config/", path)
            self.assertNotIn("/ios/Firebase/", path)
            self.assertNotIn("/DoglyadNeuralModel/Resources/", path)


if __name__ == "__main__":
    unittest.main()
