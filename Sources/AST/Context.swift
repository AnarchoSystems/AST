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

public struct Parsers {
    private let dict : [String : any AnyParser]
    public func get<Goal : ASTNode>(goal: Goal.Type) throws -> any AnyParser<Goal> {
        guard let result = dict[Goal.typeDescription] as? any AnyParser<Goal> else {
            throw ParserDefinitionError(goal: Goal.typeDescription, kind: .notDefined)
        }
        return result
    }
    public init(_ parsers: [any AnyParser]) throws {
        dict = try Dictionary(parsers.map{($0.goal, $0)}) {_, p in
            throw ParserDefinitionError(goal: p.goal, kind: .multiplyDefined)
        }
    }
}

public struct Context {
    public let parsers : Parsers
    public init(parsers: Parsers = try! .init([])) {
        self.parsers = parsers
    }
}
