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
    
    func scan(_ stream: String, do observe: (any ASTNode, ClosedRange<String.Index>) throws -> Void) throws {
        
        var scanner = Scanner<G>(actions: actions, gotos: gotos, startIndex: stream.startIndex)
        
        for index in stream.indices {
            try scanner.scan(stream[index], at: index, nextIndex: stream.index(after: index)) { observation in
                switch observation {
                case .rule(let rule, let range):
                    try observe(rule, range)
                case .accept:
                    ()
                }
            }
        }
        
        try scanner.scan(nil, at: stream.endIndex, nextIndex: stream.endIndex) { observation in
            switch observation {
            case .rule(let rule, let range):
                try observe(rule, range)
            case .accept:
                ()
            }
        }
        
    }
    
    func parse(_ stream: String) throws -> Goal? {
        var rule : (any ASTNode)?
        try scan(stream) { (ru, _) in
            rule = ru
        }
        return rule as? Goal
    }
    
}

struct UnknownRule : Error {
    let metaType : String
    let rule : String
}
