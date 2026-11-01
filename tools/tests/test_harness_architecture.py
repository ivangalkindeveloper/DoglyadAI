from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from harness.checks.architecture import python_errors, swift_checker


class PythonArchitectureTests(unittest.TestCase):
    def test_direct_relative_and_nested_imports_are_checked_in_each_backend(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for backend in ("main", "inference"):
                path = root / f"backend/{backend}/app/model/nested/value.py"
                path.parent.mkdir(parents=True)
                path.write_text("""from app.service.report import Report
from ...route import generation
from app import service
def lazy():
    import app.route.generation
""")
                errors = python_errors(path, root)
                self.assertEqual(len(errors), 4, errors)
                self.assertTrue(all("python.layer-import" in error for error in errors))

    def test_allowed_imports_comments_strings_and_composition(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder, content in (
                (
                    "model",
                    "from app.model.report import Report\n# import app.service\nexample = 'import app.route'\n",
                ),
                (
                    "service",
                    "from app.model.report import Report\nfrom app.service.validator import Validator\n",
                ),
                (
                    "core/application",
                    "from app.service.report import ReportService\nfrom app.route import report\n",
                ),
            ):
                path = root / "backend/main/app" / folder / "value.py"
                path.parent.mkdir(parents=True)
                path.write_text(content)
                self.assertEqual(python_errors(path, root), [])

    def test_service_cannot_import_route_and_invalid_python_is_not_skipped(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "backend/main/app/service/value.py"
            path.parent.mkdir(parents=True)
            path.write_text("from ..route import generation\n")
            self.assertIn("python.layer-import", python_errors(path, root)[0])
            path.write_text("def broken(:\n")
            self.assertIn("python.syntax", python_errors(path, root)[0])


class SwiftArchitectureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.binary = swift_checker()

    def run_source(
        self, source: str, context: str = ""
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / "Source.swift"
            file.write_text(source)
            other = Path(directory) / "Context.swift"
            other.write_text(context)
            return subprocess.run(
                [str(self.binary)],
                input=json.dumps({"files": [str(file)], "context": [str(other)]}),
                text=True,
                capture_output=True,
                check=False,
            )

    def test_view_methods_fragments_protocol_names_and_extensions(self) -> None:
        result = self.run_source(
            """
protocol Broken {}
struct Screen: FeatureViewProtocol {
    var body: some View { Text("body") }
    private var title: Text { Text("fragment") }
    @ViewBuilder var footer: some View { Text("footer") }
    func tapped() {}
}
extension Screen { func extra() {} }
""",
            "protocol FeatureViewProtocol: View {}",
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout.count("swift.protocol-name"), 1)
        self.assertEqual(result.stdout.count("swift.view-method"), 2)
        self.assertEqual(result.stdout.count("swift.view-fragment"), 2)

    def test_adapter_entries_modifier_style_and_nested_controller_are_allowed(
        self,
    ) -> None:
        result = self.run_source("""
protocol DViewProtocol: View {}
struct Screen: DViewProtocol {
    let content: AnyView
    var body: some View { content }
    var title: String { "func fake() {}; protocol Bad {}" }
    var titleColor: Color { .red }
    // func commentedOut() {}
    class Controller { func perform() {} }
}
struct Adapter: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {}
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? { nil }
}
struct Modifier: ViewModifier { func body(content: Content) -> some View { content } }
struct Style: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label } }
extension View { func customModifier() -> some View { self } }
extension Screen { func style() -> some View { modifier(Modifier()) } }
""")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_adapter_exemption_does_not_allow_helpers_with_different_labels(
        self,
    ) -> None:
        result = self.run_source(
            "struct Adapter: UIViewRepresentable { func makeUIView(title: String) {} }"
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("swift.view-method", result.stdout)

    def test_component_extension_cannot_hide_arbitrary_view_helper(self) -> None:
        result = self.run_source("""
struct Screen: View { var body: some View { Text("ok") } }
extension Screen { func footer() -> some View { Text("fragment") } }
""")
        self.assertEqual(result.returncode, 1)
        self.assertIn("swift.view-method", result.stdout)

    def test_invalid_swift_is_not_silently_skipped(self) -> None:
        result = self.run_source("struct Broken: View { var body: some View {")
        self.assertEqual(result.returncode, 1)
        self.assertIn("swift.syntax", result.stdout)


if __name__ == "__main__":
    unittest.main()
