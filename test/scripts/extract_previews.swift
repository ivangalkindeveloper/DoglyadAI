import Foundation
import SwiftParser
import SwiftSyntax

struct Preview: Encodable {
    let source: String
    let title: String
    let body: String
}

final class PreviewCollector: SyntaxVisitor {
    let source: String
    var previews: [Preview] = []

    init(source: String) {
        self.source = source
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(name: node.macroName.text, arguments: node.arguments, closure: node.trailingClosure)
        return .skipChildren
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        collect(name: node.macroName.text, arguments: node.arguments, closure: node.trailingClosure)
        return .skipChildren
    }

    func collect(name: String, arguments: LabeledExprListSyntax, closure: ClosureExprSyntax?) {
        guard name == "Preview", let closure
        else { return }
        let title = arguments.first?.expression.as(StringLiteralExprSyntax.self)
        let name = title.map {
            $0.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
        } ?? ""
        previews.append(Preview(source: source, title: name, body: closure.statements.trimmedDescription))
    }
}

do {
    let paths = try JSONDecoder().decode([String].self, from: FileHandle.standardInput.readDataToEndOfFile())
    var result: [Preview] = []
    for path in paths {
        let tree = Parser.parse(source: try String(contentsOfFile: path, encoding: .utf8))
        guard !tree.hasError else { throw NSError(domain: "Invalid Swift: \(path)", code: 1) }
        let collector = PreviewCollector(source: path)
        collector.walk(tree)
        result += collector.previews
    }
    FileHandle.standardOutput.write(try JSONEncoder().encode(result))
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
