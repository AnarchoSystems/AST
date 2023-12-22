//
//  Context.swift
//
//
//  Created by Markus Kasperczyk on 03.11.23.
//

public extension AnyParser {
    var goal : String {
        Goal.typeDescription
    }
}

public struct SourceLocation : Codable, Comparable {
    public var line : Int
    public var column : Int
    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
    public static func <(lhs: Self, rhs: Self) -> Bool {
        if lhs.line == rhs.line {
            return lhs.column < rhs.column
        }
        return lhs.line < rhs.line
    }
}

public struct Context {
    public let originalText : String
    public let range : ClosedRange<String.Index>
    public var rangedText : Substring {
        originalText[range]
    }
    public let sourceRange : ClosedRange<SourceLocation>
    public init(originalText: String, range: ClosedRange<String.Index>, sourceRange:  ClosedRange<SourceLocation>) {
        self.originalText = originalText
        self.range = range
        self.sourceRange = sourceRange
    }
}
