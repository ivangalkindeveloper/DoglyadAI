import Foundation
import SwiftParser
import SwiftSyntax

struct CheckInput: Decodable {
    let context: [String]
    let files: [String]
}

func typeName(_ type: TypeSyntax) -> String {
    if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
    if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
    if let opaque = type.as(SomeOrAnyTypeSyntax.self) { return typeName(opaque.constraint) }
    return type.trimmedDescription
}

final class Conformances: SyntaxVisitor {
    var parents: [String: Set<String>] = [:]

    init() { super.init(viewMode: .sourceAccurate) }

    func record(_ name: String, _ clause: InheritanceClauseSyntax?) {
        parents[name, default: []].formUnion(clause?.inheritedTypes.map { typeName($0.type) } ?? [])
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        record(typeName(node.extendedType), node.inheritanceClause)
        return .visitChildren
    }

    func has(_ name: String, _ target: String, visited: Set<String> = []) -> Bool {
        if name == target { return true }
        if visited.contains(name) { return false }
        return (parents[name] ?? []).contains { has($0, target, visited: visited.union([name])) }
    }
}

final class ArchitectureChecks: SyntaxVisitor {
    let path: String
    let locations: SourceLocationConverter
    let conformances: Conformances
    var count = 0

    init(path: String, tree: SourceFileSyntax, conformances: Conformances) {
        self.path = path
        self.locations = SourceLocationConverter(fileName: path, tree: tree)
        self.conformances = conformances
        super.init(viewMode: .sourceAccurate)
    }

    func report(_ node: some SyntaxProtocol, _ rule: String, _ message: String) {
        let location = locations.location(for: node.positionAfterSkippingLeadingTrivia)
        print("\(path):\(location.line):\(location.column): \(rule): \(message)")
        count += 1
    }

    func owner(_ node: some SyntaxProtocol) -> String? {
        var parent = node.parent
        while let current = parent {
            if let value = current.as(StructDeclSyntax.self) { return value.name.text }
            if let value = current.as(ClassDeclSyntax.self) { return value.name.text }
            if let value = current.as(EnumDeclSyntax.self) { return value.name.text }
            if let value = current.as(ExtensionDeclSyntax.self) { return typeName(value.extendedType) }
            if current.is(ProtocolDeclSyntax.self) { return nil }
            parent = current.parent
        }
        return nil
    }

    func isView(_ name: String) -> Bool {
        ["View", "UIViewRepresentable", "UIViewControllerRepresentable"].contains {
            conformances.has(name, $0)
        }
    }

    func isAdapterEntry(_ node: FunctionDeclSyntax, owner: String) -> Bool {
        let labels = node.signature.parameterClause.parameters.map { $0.firstName.text }
        let method = node.name.text
        if (conformances.has(owner, "UIViewRepresentable")
            || conformances.has(owner, "UIViewControllerRepresentable"))
            && method == "makeCoordinator" && labels.isEmpty { return true }
        for (adapter, subject, label) in [
            ("UIViewRepresentable", "UIView", "uiView"),
            ("UIViewControllerRepresentable", "UIViewController", "uiViewController")
        ] where conformances.has(owner, adapter) {
            if method == "make\(subject)" && labels == ["context"] { return true }
            if method == "update\(subject)" && labels == ["_", "context"] { return true }
            if method == "dismantle\(subject)" && labels == ["_", "coordinator"] { return true }
            if method == "sizeThatFits" && labels == ["_", label, "context"] { return true }
        }
        return false
    }

    func isModifierAPI(_ node: FunctionDeclSyntax, owner: String) -> Bool {
        var parent = node.parent
        var isExtension = false
        while let current = parent {
            if current.is(ExtensionDeclSyntax.self) { isExtension = true; break }
            if current.is(StructDeclSyntax.self) || current.is(ClassDeclSyntax.self)
                || current.is(EnumDeclSyntax.self) || current.is(FunctionDeclSyntax.self) { break }
            parent = current.parent
        }
        guard isExtension, let result = node.signature.returnClause?.type, isView(typeName(result))
        else { return false }
        // SwiftUI's View extensions are the existing modifier integration boundary.
        if owner == "View" { return true }
        // Concrete component extensions may expose a modifier through modifier(...).
        guard let statements = node.body?.statements, statements.count == 1,
              let first = statements.first
        else { return false }
        let expression = first.item.as(ExprSyntax.self)
            ?? first.item.as(ReturnStmtSyntax.self)?.expression
        guard let call = expression?.as(FunctionCallExprSyntax.self) else { return false }
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text == "modifier"
        }
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
            return member.declName.baseName.text == "modifier" && member.base?.trimmedDescription == "self"
        }
        return false
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        if !node.name.text.hasSuffix("Protocol") {
            report(node, "swift.protocol-name", "Project protocols must end with Protocol.")
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let name = owner(node), isView(name),
           !isAdapterEntry(node, owner: name), !isModifierAPI(node, owner: name) {
            report(node, "swift.view-method", "Move behavior to the view model or adapter; compose views in body.")
        }
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let name = owner(node), isView(name) else { return .visitChildren }
        let hasBuilder = node.attributes.contains {
            $0.as(AttributeSyntax.self).map { typeName($0.attributeName) == "ViewBuilder" } ?? false
        }
        for binding in node.bindings {
            guard binding.accessorBlock != nil,
                  binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text != "body"
            else { continue }
            // Stored input with didSet/willSet is not a computed view fragment.
            if case let .accessors(accessors) = binding.accessorBlock?.accessors,
               accessors.allSatisfy({ ["didSet", "willSet"].contains($0.accessorSpecifier.text) }) {
                continue
            }
            let result = binding.typeAnnotation.map { typeName($0.type) } ?? ""
            let knownView = ["AnyView", "Text", "Image", "Button", "Label", "Spacer", "Divider",
                             "HStack", "VStack", "ZStack", "Group", "ScrollView", "List", "ForEach",
                             "EmptyView", "Rectangle", "RoundedRectangle", "Circle"].contains(result)
            if hasBuilder || isView(result) || knownView {
                report(binding, "swift.view-fragment", "Extract the computed view fragment into a named View type.")
            }
        }
        return .visitChildren
    }
}

do {
    let input = try JSONDecoder().decode(CheckInput.self, from: FileHandle.standardInput.readDataToEndOfFile())
    let paths = Set(input.context).union(input.files).sorted()
    let trees = try paths.map { ($0, Parser.parse(source: try String(contentsOfFile: $0, encoding: .utf8))) }
    let conformances = Conformances()
    for (_, tree) in trees { conformances.walk(tree) }
    let selected = Set(input.files)
    var failures = 0
    for (path, tree) in trees where selected.contains(path) {
        let checks = ArchitectureChecks(path: path, tree: tree, conformances: conformances)
        if tree.hasError {
            checks.report(tree, "swift.syntax", "Fix Swift syntax before checking architecture.")
        } else {
            checks.walk(tree)
        }
        failures += checks.count
    }
    exit(failures == 0 ? 0 : 1)
} catch {
    FileHandle.standardError.write(Data("Architecture checker failed: \(error)\n".utf8))
    exit(2)
}
