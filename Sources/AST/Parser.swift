//
//  Parser.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

import Foundation


extension Character : Codable {
    
    public func encode(to encoder: Encoder) throws {
        try String(self).encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let str = try String(from: decoder)
        guard str.count == 1 else {
            throw NSError() //todo
        }
        self = str.first!
    }
    
}

public protocol AnyParser<Goal> {
    associatedtype Goal : ASTNode
    func parse(_ stream: String, context: Context, plugins: Plugins) throws -> Goal?
}

public extension AnyParser {
    func parse(_ stream: String) throws -> Goal? {
        try parse(stream, context: .init(), plugins: .init([]))
    }
    func parse(_ stream: String, context: Context) throws -> Goal? {
        try parse(stream, context: context, plugins: .init([]))
    }
    func parse(_ stream: String, plugins: Plugins) throws -> Goal? {
        try parse(stream, context: .init(), plugins: plugins)
    }
}

public struct Parser<G : Grammar, Goal : ASTNode> : Codable, Equatable {
    
    public let actions : [Character? : [Int : Action]]
    public let gotos : [String : [Int : Int]]
    
    public init(actions: [Character? : [Int : Action]],
                gotos: [String : [Int : Int]]) {
        self.actions = actions
        self.gotos = gotos
    }
    
}

public extension Parser {
    
    func scanner(startIndex: String.Index) -> Scanner<G> {
        .init(actions: actions, gotos: gotos, startIndex: startIndex)
    }
    
    func scan(_ stream: String, context: Context = .init(), plugins: Plugins = .init([]), do observe: (any ASTNode) throws -> Void) throws {
        
        var scanner = Scanner<G>(actions: actions, gotos: gotos, startIndex: stream.startIndex)
        
        for index in stream.indices {
            try scanner.scan(stream[index], at: index, nextIndex: stream.index(after: index), context: context, plugins: plugins, observe: observe)
        }
        
        try scanner.scan(nil, at: stream.endIndex, nextIndex: stream.endIndex, context: context, plugins: plugins, observe: observe)
        
    }
    
}

extension Parser : AnyParser {
    
    public func parse(_ stream: String, context: Context, plugins: Plugins) throws -> Goal? {
        var rule : (any ASTNode)?
        try scan(stream, context: context, plugins: plugins) { ru in
            rule = ru
        }
        return rule as? Goal
    }
    
}
