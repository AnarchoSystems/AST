//
//  Parser.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public struct ParserTables<G : Grammar> : Equatable, Codable {
    public let actions : [G.Symbol.RawValue? : [Int : Action]]
    public let gotos : [String : [Int : Int]]
}

public struct Parser<G : Grammar, Goal : ASTNode> {
    
    public let tables : ParserTables<G>
    public let grammar : G
    
    public init(tables: ParserTables<G>, grammar: G) {
        self.tables = tables
        self.grammar = grammar
    }
    
    public var actions : [G.Symbol.RawValue? : [Int : Action]] {
        tables.actions
    }
    public var gotos : [String : [Int : Int]] {
        tables.gotos
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
        return ASTError.parserRuntime(.unexpectedSymbol(current.map(String.init(describing:)) ?? "",
                                                        expecting: Array(Set(nonTerms))))
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
    
    private func inject(_ stack: inout Stack<any ASTNode>, _ stateStack: inout Stack<(Int, G.Symbol?, G.Context.State)>, into anything: Any) throws {
        for (_, rhs) in Mirror(reflecting: anything).children.reversed() {
            
            if let child = rhs as? Injectable,
               let toInject = stack.pop() {
                try child.inject(toInject)
                guard nil != stateStack.pop() else {
                    throw ASTError.parserDefinition(.undefinedState)
                }
            }
            
            else if let child = rhs as? _Terminal<G.Symbol> {
                guard let (_, char, _) = stateStack.pop(), let char = char else {
                    throw ASTError.parserDefinition(.undefinedState)
                }
                try child.inject(char)
            }
            
            else {
                try inject(&stack, &stateStack, into: rhs)
            }
            
        }
    }
    
    public func parse<C : Collection>(_ stream: C) throws -> Goal? where C.Element == G.Context.State.Symbol {
        var rule : (any ASTNode)?
        
        var stateStack = Stack<(Int, G.Symbol?, G.Context.State)>()
        var stack = Stack<any ASTNode>()
        
        var state = G.Context.State()
        
        stateStack.push((0, nil, state))
        
        
    iterateIndices:
        for index in Array(stream.indices) + [stream.endIndex] {
            
            let current = stream.indices.contains(index) ? stream[index] : nil
            
            while true {
                
                guard let (stateBefore, _, _) = stateStack.peek() else {
                    throw ASTError.parserDefinition(.undefinedState)
                }
                guard let dict = actions[current?.rawValue] else {
                    throw ASTError.parserDefinition(.noAction(terminal: current.map(String.init(describing:)) ?? "", state: stateBefore))
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
                        throw ASTError.parserDefinition(.unknownRule(metaType: metaType, rule: rule))
                    }
                    try inject(&stack, &stateStack, into: ru)
                    guard let (stateAfter, _, oldState) = stateStack.peek() else {
                        throw ASTError.parserDefinition(.undefinedState)
                    }
                    
                    let context = G.Context.span(from: oldState, to: state, stream: stream)
                    try stack.push(ru._onRecognize(context))
                    
                    guard let nextState = gotos[metaType]?[stateAfter] else {throw ASTError.parserDefinition(.noGoto(nonTerminal: metaType, state: stateAfter))}
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
