import Foundation
import SwiftParser
import SwiftSyntax

/// Enforces line breaks for argument lists that SwiftFormat leaves on one line.
/// SwiftFormat runs afterward to apply the project's indentation and spacing.
final class ArgumentLineBreaks: SyntaxRewriter {
    override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
        // Preserve literal content and interpolation: line breaks can invalidate
        // single-line strings or change the indentation of multiline strings.
        ExprSyntax(node)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        var result = super.visit(node).cast(FunctionCallExprSyntax.self)
        if !result.arguments.isEmpty, var rightParen = result.rightParen {
            result.arguments = wrapped(result.arguments)
            rightParen.leadingTrivia = startingOnNewLine(rightParen.leadingTrivia)
            result.rightParen = rightParen
        }
        return ExprSyntax(result)
    }

    override func visit(_ node: SubscriptCallExprSyntax) -> ExprSyntax {
        var result = super.visit(node).cast(SubscriptCallExprSyntax.self)
        if !result.arguments.isEmpty {
            result.arguments = wrapped(result.arguments)
            result.rightSquare.leadingTrivia = startingOnNewLine(result.rightSquare.leadingTrivia)
        }
        return ExprSyntax(result)
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> ExprSyntax {
        var result = super.visit(node).cast(MacroExpansionExprSyntax.self)
        if !result.arguments.isEmpty, var rightParen = result.rightParen {
            result.arguments = wrapped(result.arguments)
            rightParen.leadingTrivia = startingOnNewLine(rightParen.leadingTrivia)
            result.rightParen = rightParen
        }
        return ExprSyntax(result)
    }

    override func visit(_ node: FunctionParameterClauseSyntax) -> FunctionParameterClauseSyntax {
        var result = super.visit(node)
        if !result.parameters.isEmpty {
            result.parameters = wrapped(result.parameters)
            result.rightParen.leadingTrivia = startingOnNewLine(result.rightParen.leadingTrivia)
        }
        return result
    }

    override func visit(_ node: AttributeSyntax) -> AttributeSyntax {
        var result = super.visit(node)
        if let arguments = result.arguments?.as(LabeledExprListSyntax.self),
           !arguments.isEmpty, var rightParen = result.rightParen {
            result.arguments = .argumentList(wrapped(arguments))
            rightParen.leadingTrivia = startingOnNewLine(rightParen.leadingTrivia)
            result.rightParen = rightParen
        }
        return result
    }

    private func wrapped<List: SyntaxCollection>(_ list: List) -> List
        where List.Element: WithTrailingCommaSyntax {
        List(list.map { element in
            var result = element
            result.leadingTrivia = startingOnNewLine(result.leadingTrivia)
            if result.trailingComma == nil {
                // Put the comma before a trailing comment, including // comments.
                let trailing = result.trailingTrivia
                result.trailingTrivia = []
                result.trailingComma = .commaToken(trailingTrivia: trailing)
            }
            return result
        })
    }

    private func startingOnNewLine(_ trivia: Trivia) -> Trivia {
        // Keep comments and existing indentation. SwiftFormat finishes alignment.
        if trivia.contains(where: { piece in
            switch piece {
            case .newlines, .carriageReturns, .carriageReturnLineFeeds:
                return true
            default:
                return false
            }
        }) {
            return trivia
        }
        return .newline + trivia
    }
}

enum FormatError: Error, CustomStringConvertible {
    case invalidSyntax(String)
    case changedTokens(String)

    var description: String {
        switch self {
        case let .invalidSyntax(path):
            return "Cannot format invalid Swift syntax: \(path)"
        case let .changedTokens(path):
            return "Formatting changed tokens or comments: \(path)"
        }
    }
}

func significantContent(_ tree: SourceFileSyntax) -> [String] {
    tree.tokens(viewMode: .sourceAccurate).flatMap { token in
        let comments = (token.leadingTrivia + token.trailingTrivia).compactMap { piece -> String? in
            switch piece {
            case let .lineComment(text), let .blockComment(text),
                 let .docLineComment(text), let .docBlockComment(text):
                return text
            default:
                return nil
            }
        }
        return (token.tokenKind == .comma ? [] : [token.text]) + comments
    }
}

func formatted(_ source: String, path: String) throws -> String {
    let before = Parser.parse(source: source)
    guard !before.hasError else { throw FormatError.invalidSyntax(path) }
    let rewritten = ArgumentLineBreaks().rewrite(before).description
    let after = Parser.parse(source: rewritten)
    guard !after.hasError else { throw FormatError.invalidSyntax(path) }
    guard significantContent(before) == significantContent(after) else {
        throw FormatError.changedTokens(path)
    }
    return rewritten
}

do {
    if CommandLine.arguments.contains("--stdin") {
        let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        print(try formatted(input, path: "stdin"), terminator: "")
    } else {
        let paths = try JSONDecoder().decode([String].self, from: FileHandle.standardInput.readDataToEndOfFile())
        let check = CommandLine.arguments.contains("--check")
        // Validate every file before writing any changes.
        let changes = try paths.compactMap { path -> (String, String)? in
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let result = try formatted(source, path: path)
            return result == source ? nil : (path, result)
        }
        for (path, result) in changes {
            if check {
                print("Argument wrapping required: \(path)")
            } else {
                try result.write(toFile: path, atomically: true, encoding: .utf8)
            }
        }
        print("Argument wrapping: \(changes.count) files \(check ? "need changes" : "formatted").")
        if check, !changes.isEmpty { exit(1) }
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
