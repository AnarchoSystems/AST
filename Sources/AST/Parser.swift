//
//  Parser.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public struct Parser<G : Grammar, Goal : ASTNode> : Codable, Equatable {
    
    public let actions : [G.Symbol.RawValue? : [Int : Action]]
    public let gotos : [String : [Int : Int]]
    
    public init(actions: [G.Symbol.RawValue? : [Int : Action]],
                gotos: [String : [Int : Int]]) {
        self.actions = actions
        self.gotos = gotos
    }
    
}

private extension Parser {
    
    func gatherExeptionData(_ state: Int, current: G.Symbol?) -> Error {
        var nonTerms = Set<String>()
        var nextStates : Set<Int> = [state]
        while !nextStates.isEmpty {
            var nextNextStates : Set<Int> = []
            for ns in nextStates {
                let actions = self.actions.compactMap({ (key: G.Symbol.RawValue?, value: [Int : Action]) in
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

public extension Parser {
    var goal : String {
        Goal.typeDescription
    }
}


extension Parser {
    
    public func parse<C : Collection>(_ stream: C) throws -> Goal? where C.Element == G.Context.State.Symbol {
        var rule : (any ASTNode)?
        
        var stateStack = Stack<(Int, G.Symbol?, G.Context.State)>()
        var stack = Stack<any ASTNode>()
        
        var state = G.Context.State()
        
        stateStack.push((0, nil, state))
        
        let grammar = G()
        
    iterateIndices:
        for index in Array(stream.indices) + [stream.endIndex] {
            
            let current = stream.indices.contains(index) ? stream[index] : nil
            
            while true {
                
                guard let (stateBefore, _, _) = stateStack.peek() else {
                    throw UndefinedState(position: index)
                }
                guard let dict = actions[current?.rawValue] else {
                    throw InvalidChar(position: index, char: current)
                }
                guard let action = dict[stateBefore] else {
                    let parent = stateBefore
                    throw gatherExeptionData(parent, current: current)
                }
                
                switch action {
                    
                case .shift(let shift):
                    state.advance(current)
                    stateStack.push((shift, current, state))
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
                        
                        else if let child = rhs as? _Terminal<G.Symbol> {
                            guard let (_, char, _) = stateStack.pop(), let char = char else {
                                throw UndefinedState(position: index)
                            }
                            try child.inject(char)
                        }
                        
                    }
                    guard let (stateAfter, _, oldState) = stateStack.peek() else {
                        throw UndefinedState(position: index)
                    }
                    
                    let context = G.Context.span(from: oldState, to: state, stream: stream)
                    try stack.push(ru._onRecognize(context))
                    
                    guard let nextState = gotos[metaType]?[stateAfter] else {throw NoGoTo(nonTerm: metaType, state: stateAfter)}
                    stateStack.push((nextState, current, state))
                    
                case .accept:
                    
                    rule = stack.peek()!
                    break iterateIndices
                }
                
            }
            
        }
        
        return rule as? Goal
    }
    
}
