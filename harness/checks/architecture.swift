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

func storedPropertyNames(_ members: MemberBlockItemListSyntax) -> [String] {
    members.flatMap { member -> [String] in
        guard let property = member.decl.as(VariableDeclSyntax.self),
              !property.modifiers.contains(where: { ["static", "class"].contains($0.name.text) })
        else { return [] }
        return property.bindings.compactMap { binding in
            if let block = binding.accessorBlock {
                switch block.accessors {
                case .getter: return nil
                case let .accessors(values):
                    guard values.allSatisfy({ ["willSet", "didSet"].contains($0.accessorSpecifier.text) }) else { return nil }
                @unknown default: return nil
                }
            }
            return binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        }
    }
}

final class Conformances: SyntaxVisitor {
    var parents: [String: Set<String>] = [:]
    var properties: [String: [String]] = [:]

    init() { super.init(viewMode: .sourceAccurate) }

    func record(_ name: String, _ clause: InheritanceClauseSyntax?) {
        parents[name, default: []].formUnion(clause?.inheritedTypes.map { typeName($0.type) } ?? [])
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.inheritanceClause)
        properties[node.name.text] = storedPropertyNames(node.memberBlock.members)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.inheritanceClause)
        properties[node.name.text] = storedPropertyNames(node.memberBlock.members)
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

final class ViewSwitchExpressions: SyntaxVisitor {
    var expressions: [SwitchExprSyntax] = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        expressions.append(node)
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
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

    func isAccessibilityMetadata(_ name: String) -> Bool {
        name.hasPrefix("accessibility") && name != "accessibility"
    }

    override func visit(_ node: MemberBlockItemListSyntax) -> SyntaxVisitorContinueKind {
        let fields = storedPropertyNames(node)
        if let first = fields.firstIndex(where: isAccessibilityMetadata),
           fields.dropFirst(first).contains(where: { !isAccessibilityMetadata($0) }) {
            report(node, "swift.accessibility-field-order", "Place accessibility fields after all other stored fields.")
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let labels = node.arguments.map { $0.label?.text ?? "" }
        if let first = labels.firstIndex(where: isAccessibilityMetadata),
           labels.dropFirst(first).contains(where: { !isAccessibilityMetadata($0) }) || node.trailingClosure != nil {
            report(node, "swift.accessibility-argument-order", "Pass accessibility arguments last; pass view-builder content as a labeled argument before them.")
        }
        if path.contains("/ios/Doglyad/") || path.hasPrefix("ios/Doglyad/"),
           node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "disabled" {
            report(node, "swift.explicit-disabled", "Pass isDisabled to each interactive design-system component instead of disabling a view or container.")
        }
        return .visitChildren
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

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let labels = node.signature.parameterClause.parameters.map { $0.firstName.text }
        if let first = labels.firstIndex(where: isAccessibilityMetadata),
           labels.dropFirst(first).contains(where: { !isAccessibilityMetadata($0) }) {
            report(node, "swift.accessibility-parameter-order", "Place accessibility parameters last in the initializer.")
        }
        var parent = node.parent
        var fields: [String] = []
        while let value = parent {
            if let value = value.as(ClassDeclSyntax.self) {
                fields = storedPropertyNames(value.memberBlock.members); break
            }
            if let value = value.as(StructDeclSyntax.self) {
                fields = storedPropertyNames(value.memberBlock.members); break
            }
            if let value = value.as(ExtensionDeclSyntax.self) {
                fields = conformances.properties[typeName(value.extendedType)] ?? []; break
            }
            parent = value.parent
        }
        guard !fields.isEmpty, let body = node.body else { return .visitChildren }
        let parameters = node.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }
        var shadowed = Set(parameters)
        var assignments: [(String, String)] = []
        for statement in body.statements {
            if let declaration = statement.item.as(VariableDeclSyntax.self) {
                shadowed.formUnion(declaration.bindings.compactMap { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text })
            }
            guard let expression = statement.item.as(SequenceExprSyntax.self) else { continue }
            let parts = Array(expression.elements)
            guard parts.count >= 3, parts[1].is(AssignmentExprSyntax.self) else { continue }
            let raw: String
            if let member = parts[0].as(MemberAccessExprSyntax.self), member.base?.trimmedDescription == "self" {
                raw = member.declName.baseName.text
            } else if let reference = parts[0].as(DeclReferenceExprSyntax.self), !shadowed.contains(reference.baseName.text) {
                raw = reference.baseName.text
            } else { continue }
            let field = fields.contains(raw) ? raw : raw.hasPrefix("_") ? String(raw.dropFirst()) : raw
            if fields.contains(field) { assignments.append((field, parts.dropFirst(2).map(\.description).joined().trimmingCharacters(in: .whitespacesAndNewlines))) }
        }
        let mapped = parameters.compactMap { parameter -> String? in
            if fields.contains(parameter) { return parameter }
            return assignments.first { $0.1 == parameter }?.0
        }
        if mapped != mapped.sorted(by: { fields.firstIndex(of: $0)! < fields.firstIndex(of: $1)! }) {
            report(node, "swift.initializer-parameter-order", "Order initializer parameters by their stored property declarations.")
        }
        let assigned = assignments.map(\.0)
        if assigned != assigned.sorted(by: { fields.firstIndex(of: $0)! < fields.firstIndex(of: $1)! }) {
            report(node, "swift.initializer-assignment-order", "Assign stored properties in declaration order; compute dependent values in local variables first.")
        }
        return .visitChildren
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
            if binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body",
               let accessors = binding.accessorBlock {
                let switches = ViewSwitchExpressions()
                switches.walk(accessors)
                for expression in switches.expressions.dropFirst() {
                    report(expression, "swift.view-state-switch", "Keep at most one switch in body; extract another presentation area into a named View.")
                }
            }
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
