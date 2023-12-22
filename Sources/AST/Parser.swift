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
    func parse(_ stream: String) throws -> Goal?
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

private extension Parser {
    
    func gatherExeptionData(_ state: Int, current: Character?) -> Error {
        var nonTerms = Set<String>()
        var nextStates : Set<Int> = [state]
        while !nextStates.isEmpty {
            var nextNextStates : Set<Int> = []
            for ns in nextStates {
                let actions = self.actions.compactMap({ (key: Character?, value: [Int : Action]) in
                    value[ns].map{(key, $0)}
                })
                for (_, action) in actions {
                    switch action {
                    case .shift(let int):
                        nextNextStates.insert(int)
                    case .reduce(_, let meta):
                        nonTerms.insert(meta)
                    case .accept:
                        continue
                    }
                }
            }
            nextStates = nextNextStates
        }
        return UnexpectedChar(char: current, expecting: Set(nonTerms))
    }
    
}

public extension Rule {
    var kind : String {
        String(describing: Self.self)
    }
}


extension Parser : AnyParser {
    
    public func parse(_ stream: String) throws -> Goal? {
        var rule : (any ASTNode)?
        
        var stateStack = Stack<(Int, String.Index, SourceLocation)>()
        var stack = Stack<any ASTNode>()
        
        var location = SourceLocation(line: 0, column: 0)
        
        stateStack.push((0, stream.startIndex, location))
        
        let grammar = G()
        
    iterateIndices:
        for index in Array(stream.indices) + [stream.endIndex] {
            
            let nextIndex = index < stream.endIndex ? stream.index(after: index) : stream.endIndex
            let current = stream.indices.contains(index) ? stream[index] : nil
            
            if current == "\n" {
                location.line += 1
                location.column = 0
            }
            else {
                location.column += 1
            }
            
            while true {
                
                guard let (stateBefore, _, _) = stateStack.peek() else {
                    throw UndefinedState(position: index)
                }
                guard let dict = actions[current] else {
                    throw InvalidChar(position: index, char: current ?? "$")
                }
                guard let action = dict[stateBefore] else {
                    let parent = stateBefore
                    throw gatherExeptionData(parent, current: current)
                }
                
                switch action {
                    
                case .shift(let shift):
                    stateStack.push((shift, nextIndex, location))
                    continue iterateIndices
                    
                case .reduce(let rule, let metaType):
                    guard let ru = grammar.rules[metaType]?[rule] else {
                        throw UnknownRule(metaType: metaType, rule: rule)
                    }
                    for (_, rhs) in Mirror(reflecting: ru).children.reversed() {
                        
                        if let child = rhs as? Injectable,
                           let toInject = stack.pop() {
                            try child.inject(toInject)
                            guard nil != stateStack.pop() else {
                                throw UndefinedState(position: index)
                            }
                        }
                        
                        if rhs is Terminal {
                            guard nil != stateStack.pop() else {
                                throw UndefinedState(position: index)
                            }
                        }
                        
                    }
                    guard let (stateAfter, startIndex, startLocation) = stateStack.peek() else {
                        throw UndefinedState(position: index)
                    }
                    
                    let context = Context(originalText: stream,
                                          range: startIndex...index,
                                          sourceRange: startLocation...location)
                    try stack.push(ru.onRecognize(context: context))
                    
                    guard let nextState = gotos[metaType]?[stateAfter] else {throw NoGoTo(nonTerm: metaType, state: stateAfter)}
                    stateStack.push((nextState, index, location))
                    
                case .accept:
                    
                    rule = stack.peek()!
                    break iterateIndices
                }
                
            }
        }
        
        return rule as? Goal
    }
    
}
