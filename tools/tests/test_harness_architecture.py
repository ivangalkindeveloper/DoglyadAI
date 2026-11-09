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
        self, source: str, context: str = "", relative_path: str = "Source.swift"
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / relative_path
            file.parent.mkdir(parents=True, exist_ok=True)
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

    def test_accessibility_metadata_follows_fields_and_content_arguments(self) -> None:
        result = self.run_source('''
struct Control: View {
    let accessibilityIdentifier: String?
    let title: String
    var body: some View { Button(accessibilityIdentifier: "control", action: {}) }
}
''')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("swift.accessibility-field-order", result.stdout)
        self.assertIn("swift.accessibility-argument-order", result.stdout)
        trailing = self.run_source('let button = DCard(accessibilityIdentifier: "card") { Text("content") }')
        self.assertIn("swift.accessibility-argument-order", trailing.stdout)
        initializer = self.run_source('struct Control { init(accessibilityIdentifier: String?, transient: Int) {} }')
        self.assertIn("swift.accessibility-parameter-order", initializer.stdout)

    def test_labeled_content_and_domain_availability_are_not_metadata_errors(self) -> None:
        result = self.run_source('''
struct Control: View {
    let title: String
    let accessibilityIdentifier: String?
    var body: some View { DCard(action: {}, content: { Text(title) }, accessibilityIdentifier: accessibilityIdentifier) }
}
struct Model { let accessibility: Int; let contextLength: Int }
''')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_native_disabled_is_confined_to_the_design_system(self) -> None:
        source = 'struct Control: View { var body: some View { Button("Tap", action: {}).disabled(true) } }'
        application = self.run_source(source, relative_path="ios/Doglyad/Control.swift")
        self.assertIn("swift.explicit-disabled", application.stdout)
        component = self.run_source(source, relative_path="Doglyad/ios/DoglyadUI/Control.swift")
        self.assertEqual(component.returncode, 0, component.stdout + component.stderr)

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

    def test_nested_and_value_switches_share_the_view_body_limit(self) -> None:
        result = self.run_source("""
struct Screen: View {
    var body: some View {
        let isLoading = switch state { case .loading: true; default: false }
        switch state {
        case .loaded:
            switch provider { case .apple: Text("Apple"); default: Text("Other") }
        default: Text("Loading")
        }
    }
}
""")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout.count("swift.view-state-switch"), 2)

    def test_each_composed_view_may_have_its_own_switch(self) -> None:
        result = self.run_source("""
struct Screen: View {
    var body: some View {
        switch state { case .loaded: Footer(); default: Text("Loading") }
    }
}
struct Footer: View {
    var body: some View {
        switch provider { case .apple: Text("Apple"); default: Text("Other") }
    }
}
struct Adapter: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        switch first { case true: break; default: break }
        switch second { case true: break; default: break }
        return UIView()
    }
}
""")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_initializer_parameters_and_assignments_follow_fields(self) -> None:
        result = self.run_source("""
struct Value {
    let first: Int
    let second: Int
    init(second: Int, first: Int) {
        self.second = second
        self.first = first
    }
}
""")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("swift.initializer-parameter-order", result.stdout)
        self.assertIn("swift.initializer-assignment-order", result.stdout)

    def test_initializer_ignores_computed_static_and_local_properties(self) -> None:
        result = self.run_source("""
class Value {
    static let shared = 1
    var computed: Int { 1 }
    let first: Int
    var second: Int { didSet {} }
    init(first: Int, second: Int) {
        var first = first
        first = first + 1
        self.first = first
        self.second = second
    }
}
""")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_initializer_maps_wrapper_storage_and_external_labels(self) -> None:
        result = self.run_source("""
struct Value {
    @Binding var first: Int
    let second: Int
    init(second: Int, value first: Binding<Int>) {
        self.second = second
        self._first = first
    }
}
""")
        self.assertIn("swift.initializer-parameter-order", result.stdout)
        self.assertIn("swift.initializer-assignment-order", result.stdout)

    def test_initializer_maps_renamed_parameters_to_assigned_fields(self) -> None:
        result = self.run_source("""
struct Value {
    let first: Int
    let second: Int
    init(later: Int, earlier: Int) {
        self.first = earlier
        self.second = later
    }
}
""")
        self.assertIn("swift.initializer-parameter-order", result.stdout)
        self.assertNotIn("swift.initializer-assignment-order", result.stdout)

    def test_extension_initializer_uses_stored_fields_from_context(self) -> None:
        result = self.run_source(
            "extension Value { init(second: Int, first: Int) { self.second = second; self.first = first } }",
            "struct Value { let first: Int; let second: Int }",
        )
        self.assertIn("swift.initializer-parameter-order", result.stdout)
        self.assertIn("swift.initializer-assignment-order", result.stdout)

    def test_each_initializer_overload_is_checked(self) -> None:
        result = self.run_source("""
struct Value {
    let first: Int
    let second: Int
    init(first: Int) { self.first = first; second = 0 }
    init(first: Int, second: Int) { self.first = first; self.second = second }
}
""")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_invalid_swift_is_not_silently_skipped(self) -> None:
        result = self.run_source("struct Broken: View { var body: some View {")
        self.assertEqual(result.returncode, 1)
        self.assertIn("swift.syntax", result.stdout)


if __name__ == "__main__":
    unittest.main()
