//
//  Parser.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public protocol AnyParser<Ctx, Goal> {
    associatedtype Ctx : ContextProtocol
    associatedtype Goal : ASTNode
    func parse<C : Collection>(_ stream: C) -> Result<Goal, Errors> where C.Element == Ctx.State.Symbol
}

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
}

private extension Parser {
    
    struct IterationData {
        let tables : ParserTables<G>
        let grammar : G
        var stateStack = Stack<(Int, G.Symbol?, G.Ctx.State)>()
        var stack = Stack<any ASTNode>()
        var savePoints = [G.Symbol.RawValue : IterationData]()
        
        var actions : [G.Symbol.RawValue? : [Int : Action]] {
            tables.actions
        }
        var gotos : [String : [Int : Int]] {
            tables.gotos
        }
        
        mutating func advance<C : Collection>(stream: C, symbol current: G.Ctx.State.Symbol?, state: inout G.Ctx.State) throws -> Goal? where C.Element == G.Ctx.State.Symbol {
            
            if let current, grammar.savePoints.contains(current.rawValue) {
                savePoints[current.rawValue] = self
            }
            
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
                    return nil
                    
                case .reduce(let rule, let metaType):
                    guard let ru = grammar.rules[metaType]?[rule] else {
                        throw ASTError.parserDefinition(.unknownRule(metaType: metaType, rule: rule))
                    }
                    try inject(&stack, &stateStack, into: ru)
                    guard let (stateAfter, _, oldState) = stateStack.peek() else {
                        throw ASTError.parserDefinition(.undefinedState)
                    }
                    
                    let context = G.Ctx.span(from: oldState, to: state, stream: stream)
                    try stack.push(ru._onRecognize(any: context))
                    
                    flush(ru)
                    
                    guard let nextState = gotos[metaType]?[stateAfter] else {throw ASTError.parserDefinition(.noGoto(nonTerminal: metaType, state: stateAfter))}
                    stateStack.push((nextState, current, state))
                    
                case .accept:
                    
                    return stack.peek() as? Goal
                }
                
            }
            
        }
        
        mutating func recover(symbol: G.Ctx.State.Symbol) -> Bool {
            guard let savePoint = savePoints[symbol.rawValue] else {
                return false
            }
            self = savePoint
            return true
        }
        
        private func inject(_ stack: inout Stack<any ASTNode>, _ stateStack: inout Stack<(Int, G.Symbol?, G.Ctx.State)>, into anything: Any) throws {
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
        
        private func flush(_ any: Any) {
            for (_, rhs) in Mirror(reflecting: any).children {
                if let child = rhs as? Injectable {
                    child.flush()
                }
                else {
                    flush(rhs)
                }
            }
        }
        
        private func gatherExeptionData(_ state: Int, current: G.Symbol?) -> Error {
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
    
}

public extension Constructor {
    var kind : String {
        String(describing: Self.self)
    }
}

public extension Parser {
    var goal : String {
        Goal.typeDescription
    }
}

public struct Errors : Error {
    public var problems : [Error]
    public init(_ problems: [Error] = []) {
        self.problems = problems
    }
}

extension Parser : AnyParser {
    
    public typealias Ctx = G.Ctx
    
    public func parse<C : Collection>(_ stream: C) -> Result<Goal, Errors> where C.Element == G.Ctx.State.Symbol {
         
        var iterationData = IterationData(tables: tables, grammar: grammar)
        var state = G.Ctx.State()
        
        iterationData.stateStack.push((0, nil, state))
        
        var errors = Errors()
        var didEncounterError = false
        
        for index in Array(stream.indices) + [stream.endIndex] {
            
            let current = stream.indices.contains(index) ? stream[index] : nil
            
            if didEncounterError {
                if let current {
                    didEncounterError = !iterationData.recover(symbol: current)
                }
                else {
                    return .failure(errors)
                }
            }
            else {
                do {
                    if let node = try iterationData.advance(stream: stream, symbol: current, state: &state) {
                        return .success(node)
                    }
                }
                catch {
                    errors.problems.append(error)
                    didEncounterError = true
                }
            }
        }
        
        return .failure(errors.problems.isEmpty ? Errors([ASTError.parserDefinition(.noOutput)]) : errors)
        
    }
    
}
