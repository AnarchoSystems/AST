//
//  Parser.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

import Foundation

public enum Action : Codable, Equatable {
    case shift(Int)
    case reduce(rule: String, recognized: String)
    case accept
    
    enum RawType : String, Codable {
        case shift, reduce, accept
    }
    struct TypeCoder : Codable {
        let type : RawType
    }
    enum _Shift : String, Codable {case shift}
    struct Shift : Codable {
        let type : _Shift
        let newState : Int
    }
    enum _Reduce : String, Codable {case reduce}
    struct Reduce : Codable {
        let type : _Reduce
        let rule : String
        let recognized : String
    }
    
    public init(from decoder: Decoder) throws {
        let type = try TypeCoder(from: decoder)
        switch type.type {
        case .shift:
            let this = try Shift(from: decoder)
            self = .shift(this.newState)
        case .reduce:
            let this = try Reduce(from: decoder)
            self = .reduce(rule: this.rule, recognized: this.recognized)
        case .accept:
            self = .accept
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .shift(let newState):
            try Shift(type: .shift, newState: newState).encode(to: encoder)
        case .reduce(let rule, let meta):
            try Reduce(type: .reduce, rule: rule, recognized: meta).encode(to: encoder)
        case .accept:
            try TypeCoder(type: .accept).encode(to: encoder)
        }
    }
}

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

public extension Parser {
    
    func withStack<Out>(_ stream: String, do construction: (any Rule, inout Stack<Out>) throws -> Void) throws ->Stack<Out> {
        
        let G = G()
        
        var index = stream.startIndex
        var current = stream.first
        
        var stateStack = Stack<Int>()
        stateStack.push(0)
        var outStack = Stack<Out>()
        
    loop:
        while true {
            guard let stateBefore = stateStack.peek() else {
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
                stateStack.push(shift)
                index = stream.index(after: index)
                current = stream.indices.contains(index) ? stream[index] : nil
                
            case .reduce(let rule, let metaType):
                guard let dict = G.rules[metaType],
                let ru = dict[rule] else {
                    throw UnknownRule(metaType: metaType, rule: rule)
                }
                for (_, child) in Mirror(reflecting: ru).children {
                    guard nil != child as? ExprProperty else {continue}
                    _ = stateStack.pop()
                }
                guard let stateAfter = stateStack.peek() else {
                    throw UndefinedState(position: index)
                }
                try construction(ru, &outStack)
                guard let nextState = gotos[metaType]?[stateAfter] else {throw NoGoTo(nonTerm: metaType, state: stateAfter)}
                stateStack.push(nextState)
                
            case .accept:
                break loop
            }
            
        }
        return outStack
    }
    
    func parse(_ stream: String) throws -> Goal? {
        var stack = try withStack(stream) { (rule, stack : inout Stack<any ASTNode>) in
            
            for (_, rhs) in Mirror(reflecting: rule).children.reversed() {
                guard let child = rhs as? Injectable,
                      let toInject = stack.pop() else {
                    continue
                }
                try child.inject(toInject)
            }
            
            stack.push(try rule.onRecognize())
            
        }
        return stack.pop() as? Goal
    }
    
}

struct UnknownRule : Error {
    let metaType : String
    let rule : String
}
