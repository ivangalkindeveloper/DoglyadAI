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

    def test_initializer_spacing_and_body(self) -> None:
        result = self.format(
            "final class ActiveState {\n"
            "let status: Int\n"
            "init(status: Int) { self.status = status }\n"
            "}\n"
        )
        self.assertEqual(
            result,
            "final class ActiveState {\n"
            "    let status: Int\n"
            "\n"
            "    init(\n"
            "        status: Int,\n"
            "    ) {\n"
            "        self.status = status\n"
            "    }\n"
            "}\n",
        )
        self.assertEqual(self.format(result), result)

    def test_class_member_order_preserves_properties_methods_and_comments(self) -> None:
        source = (
            "class Example {\n"
            "func firstMethod() {}\n"
            "// First property\n"
            "let first = 1\n"
            "/// Creates an example.\n"
            "init(value: Int) { self.value = value }\n"
            "private let second = 2\n"
            "/// Selected value.\n"
            "let value: Int\n"
            "func secondMethod() {}\n"
            "}\n"
        )
        result = self.format(source)
        declarations = [
            "let first = 1",
            "private let second = 2",
            "let value: Int",
            "init(",
            "func firstMethod()",
            "func secondMethod()",
        ]
        positions = [result.index(declaration) for declaration in declarations]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("/// Selected value.\n    let value", result)
        self.assertIn("\n\n    /// Creates an example.\n    init(", result)
        self.assertIn("// First property\n    let first", result)
        for comment in (
            "// First property",
            "/// Creates an example.",
            "/// Selected value.",
        ):
            self.assertEqual(result.count(comment), 1)
        self.assertEqual(self.format(result), result)

    def test_conditional_members_preserve_initialization_order(self) -> None:
        result = self.format(
            "class Example {\n"
            "let first = 1\n"
            "#if DEBUG\n"
            "let second = 2\n"
            "#endif\n"
            "init() {}\n"
            "let third = 3\n"
            "}\n"
        )
        self.assertLess(result.index("let first"), result.index("let second"))
        self.assertLess(result.index("let second"), result.index("init()"))
        self.assertLess(result.index("init()"), result.index("let third"))
        self.assertEqual(self.format(result), result)

    def test_computed_properties_follow_initializers_and_precede_methods(self) -> None:
        result = self.format(
            "class Example {\n"
            "func firstMethod() {}\n"
            "/// Derived value.\n"
            "var doubled: Int { value * 2 }\n"
            "var value = 1 { willSet {} didSet {} }\n"
            "var selected: Int { get { value } set { value = newValue } }\n"
            "let callback: () -> Int = { 3 }\n"
            "init() {}\n"
            "subscript(index: Int) -> Int { value + index }\n"
            "func secondMethod() {}\n"
            "}\n"
        )
        declarations = [
            "var value = 1",
            "let callback:",
            "init()",
            "var doubled:",
            "var selected:",
            "subscript(",
            "func firstMethod()",
            "func secondMethod()",
        ]
        positions = [result.index(declaration) for declaration in declarations]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("\n\n    init()", result)
        self.assertIn("\n\n    /// Derived value.\n    var doubled:", result)
        self.assertIn("\n\n    func firstMethod()", result)
        self.assertIn("\n\n    func secondMethod()", result)
        self.assertEqual(self.format(result), result)

    def test_blank_lines_between_empty_methods_and_initializers(self) -> None:
        result = self.format(
            "class Example {\n"
            "init() {}\n"
            "init(value: Int) {}\n"
            "func first() {}\n"
            "/// Second action.\n"
            "@MainActor func second() {}\n"
            "deinit {}\n"
            "}\n"
        )
        self.assertIn("init() {}\n\n    init(", result)
        self.assertIn("\n\n    func first()", result)
        self.assertIn(
            "\n\n    /// Second action.\n    @MainActor func second()", result
        )
        self.assertIn("\n\n    deinit", result)
        self.assertEqual(self.format(result), result)

    def test_accessors_without_initializers_follow_fields(self) -> None:
        result = self.format(
            "class Example {\n"
            "var count: Int { 1 }\n"
            "static let shared = Example()\n"
            "static var isAvailable: Bool { true }\n"
            "}\n"
        )
        self.assertLess(result.index("static let shared"), result.index("var count:"))
        self.assertIn("static let shared = Example()\n\n    var count:", result)
        self.assertEqual(self.format(result), result)

    def test_nested_classes_have_independent_member_order(self) -> None:
        result = self.format(
            "class Outer {\n"
            "var value: Int { 1 }\n"
            "init() {}\n"
            "class Inner {\n"
            "func read() -> Int { value }\n"
            "var value: Int { stored }\n"
            "init() {}\n"
            "let stored = 2\n"
            "}\n"
            "}\n"
        )
        self.assertLess(result.index("init()"), result.index("var value:"))
        inner = result[result.index("class Inner") :]
        declarations = ["let stored", "init()", "var value:", "func read()"]
        positions = [inner.index(declaration) for declaration in declarations]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(self.format(result), result)

    def test_extensions_follow_member_order_without_merging_blocks(self) -> None:
        result = self.format(
            "class Example {}\n"
            "extension Example {\n"
            "func first() {}\n"
            "/// Stored configuration.\n"
            "static let firstValue = 1\n"
            "var value: Int { 1 }\n"
            "static let secondValue = 2\n"
            "convenience init(value: Int) { self.init() }\n"
            "func second() {}\n"
            "}\n"
            "extension Example { func third() {} }\n"
        )
        declarations = [
            "static let firstValue",
            "static let secondValue",
            "convenience init(",
            "var value:",
            "func first()",
            "func second()",
            "func third()",
        ]
        positions = [result.index(declaration) for declaration in declarations]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("/// Stored configuration.\n    static let firstValue", result)
        self.assertEqual(result.count("extension Example"), 2)
        self.assertEqual(self.format(result), result)

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
class Model {
    func currentValue() -> Int { value }
    var selected: Int { get { value } set { value = newValue } }
    init(value: Int) { self.value = value }
    var value: Int { willSet {} didSet {} }
    subscript(index: Int) -> Int { value + index }
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
