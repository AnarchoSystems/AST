//
//  Scanner.swift
//  
//
//  Created by Markus Kasperczyk on 03.11.23.
//

import Foundation

public struct Scanner<G : Grammar> {
    
    public let actions : [Character? : [Int : Action]]
    public let gotos : [String : [Int : Int]]
    
    private(set) public var stateStack : Stack<(Int, String.Index)>
    private(set) public var stack : Stack<any ASTNode>
    
    let grammar = G()
    
    init(actions: [Character? : [Int : Action]], gotos: [String : [Int : Int]], stateStack: Stack<(Int, String.Index)> = .init(), startIndex: String.Index, stack: Stack<any ASTNode> = .init()) {
        self.actions = actions
        self.gotos = gotos
        self.stateStack = stateStack
        self.stateStack.push((0, startIndex))
        self.stack = stack
    }
    
}

private extension Scanner {
    
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

public enum ScannerObservation {
    case rule(any ASTNode, ClosedRange<String.Index>)
    case accept
}

public extension Scanner {
    
    mutating func scan(_ current: Character?, at index: String.Index, nextIndex: String.Index, observe: (ScannerObservation) throws -> Void) throws {
        
    while true {
        
            guard let (stateBefore, _) = stateStack.peek() else {
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
                stateStack.push((shift, nextIndex))
                return
                
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
                guard let (stateAfter, startIndex) = stateStack.peek() else {
                    throw UndefinedState(position: index)
                }
                
                stack.push(try ru.onRecognize(in: startIndex...index))
                try observe(.rule(stack.peek()!, startIndex...index))
                
                guard let nextState = gotos[metaType]?[stateAfter] else {throw NoGoTo(nonTerm: metaType, state: stateAfter)}
                stateStack.push((nextState, index))
                
            case .accept:
                try observe(.rule(stack.peek()!, stateStack.peek()!.1...nextIndex))
                return
            }
            
        }
        
    }
    
}
