//
//  Context.swift
//
//
//  Created by Markus Kasperczyk on 03.11.23.
//

public protocol IteratorState {
    associatedtype Symbol : SymbolProtocol
    init()
    mutating func advance(_ symbol: Symbol?)
}

public protocol ContextProtocol {
    associatedtype State : IteratorState
    static func span<C : Collection>(from: State, to: State, stream: C) -> Self where C.Element == State.Symbol
}

public struct SourceLocation : Codable, Comparable, IteratorState {
    public var line = 0
    public var column = 0
    public init() {}
    public mutating func advance(_ symbol: Character?) {
        guard let char = symbol else {
            return
        }
        if char == "\n" {
            line += 1
            column = 0
        }
        else {
            column += 1
        }
    }
    public static func <(lhs: Self, rhs: Self) -> Bool {
        if lhs.line == rhs.line {
            return lhs.column < rhs.column
        }
        return lhs.line < rhs.line
    }
}

public struct Context : ContextProtocol {
    public typealias State = SourceLocation
    public let originalText : String
    public let sourceRange : ClosedRange<SourceLocation>
    public static func span<C>(from: SourceLocation, to: SourceLocation, stream: C) -> Context where C : Collection, C.Element == State.Symbol {
        if let stream = stream as? String {
            return Context(originalText: stream, sourceRange: from...to)
        }
        return Context(originalText: String(Array(stream)), sourceRange: from...to)
    }
}
