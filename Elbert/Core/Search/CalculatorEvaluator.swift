//
//  CalculatorEvaluator.swift
//  Elbert
//

import Foundation

struct CalculatorEvaluator {
    enum EvaluationError: Error {
        case invalidExpression
        case divisionByZero
    }

    static func evaluate(_ input: String) throws -> Double {
        let expression = normalizedExpression(from: input)
        guard !expression.isEmpty else {
            throw EvaluationError.invalidExpression
        }

        var parser = Parser(expression: expression)
        let value = try parser.parse()
        guard value.isFinite else {
            throw EvaluationError.invalidExpression
        }
        return value
    }

    static func formattedResult(for input: String) throws -> String {
        let value = try evaluate(input)
        return format(value)
    }

    static func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 1e-12 {
            return String(Int64(value.rounded()))
        }
        return String(format: "%.12g", value)
    }

    private static func normalizedExpression(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=") {
            return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}

private struct Parser {
    private let tokens: [CalcToken]
    private var index: Int = 0

    init(expression: String) {
        var lexer = Lexer(expression: expression)
        self.tokens = lexer.lexedTokens()
    }

    mutating func parse() throws -> Double {
        let value = try parseExpression()
        guard index == tokens.count else {
            throw CalculatorEvaluator.EvaluationError.invalidExpression
        }
        return value
    }

    private mutating func parseExpression() throws -> Double {
        var value = try parseTerm()
        while true {
            if match(.plus) {
                value += try parseTerm()
            } else if match(.minus) {
                value -= try parseTerm()
            } else {
                break
            }
        }
        return value
    }

    private mutating func parseTerm() throws -> Double {
        var value = try parsePower()
        while true {
            if match(.multiply) {
                value *= try parsePower()
            } else if match(.divide) {
                let rhs = try parsePower()
                guard rhs != 0 else {
                    throw CalculatorEvaluator.EvaluationError.divisionByZero
                }
                value /= rhs
            } else {
                break
            }
        }
        return value
    }

    private mutating func parsePower() throws -> Double {
        var value = try parseUnary()
        if match(.power) {
            let exponent = try parsePower()
            value = Foundation.pow(value, exponent)
        }
        return value
    }

    private mutating func parseUnary() throws -> Double {
        if match(.plus) {
            return try parseUnary()
        }
        if match(.minus) {
            return -(try parseUnary())
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws -> Double {
        guard index < tokens.count else {
            throw CalculatorEvaluator.EvaluationError.invalidExpression
        }

        switch tokens[index] {
        case .number(let value):
            index += 1
            return value
        case .leftParen:
            index += 1
            let value = try parseExpression()
            guard match(.rightParen) else {
                throw CalculatorEvaluator.EvaluationError.invalidExpression
            }
            return value
        default:
            throw CalculatorEvaluator.EvaluationError.invalidExpression
        }
    }

    private mutating func match(_ expected: CalcToken) -> Bool {
        guard index < tokens.count else { return false }
        if tokens[index].matches(expected) {
            index += 1
            return true
        }
        return false
    }
}

private struct Lexer {
    private let chars: [Character]
    private var index: Int = 0

    init(expression: String) {
        self.chars = Array(expression)
    }

    mutating func lexedTokens() -> [CalcToken] {
        var output: [CalcToken] = []

        while index < chars.count {
            let ch = chars[index]

            if ch.isWhitespace {
                index += 1
                continue
            }

            if ch.isNumber || ch == "." {
                if let value = parseNumber() {
                    output.append(.number(value))
                } else {
                    return []
                }
                continue
            }

            switch ch {
            case "+": output.append(.plus)
            case "-": output.append(.minus)
            case "*": output.append(.multiply)
            case "/": output.append(.divide)
            case "^": output.append(.power)
            case "(": output.append(.leftParen)
            case ")": output.append(.rightParen)
            default:
                return []
            }
            index += 1
        }

        return output
    }

    private mutating func parseNumber() -> Double? {
        let start = index
        var seenDot = false

        while index < chars.count {
            let ch = chars[index]
            if ch == "." {
                if seenDot {
                    return nil
                }
                seenDot = true
                index += 1
                continue
            }
            if ch.isNumber {
                index += 1
            } else {
                break
            }
        }

        let text = String(chars[start..<index])
        guard !text.isEmpty, text != "." else { return nil }
        return Double(text)
    }
}

private enum CalcToken {
    case number(Double)
    case plus
    case minus
    case multiply
    case divide
    case power
    case leftParen
    case rightParen
}

private extension CalcToken {
    func matches(_ other: Self) -> Bool {
        switch (self, other) {
        case (.plus, .plus),
             (.minus, .minus),
             (.multiply, .multiply),
             (.divide, .divide),
             (.power, .power),
             (.leftParen, .leftParen),
             (.rightParen, .rightParen):
            return true
        case (.number, .number):
            return true
        default:
            return false
        }
    }
}
