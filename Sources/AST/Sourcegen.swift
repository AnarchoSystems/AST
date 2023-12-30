//
//  Sourcegen.swift
//
//
//  Created by Markus Kasperczyk on 29.12.23.
//

public struct IterationData<G : Grammar, Output : ASTNode> {
    public var stateStack = Stack<(G.Ctx.State, G.Symbol?, any ParserState<G, Output>)>()
    public var stack = Stack<any ASTNode>()
    public var savePoints = [G.Symbol.RawValue : IterationData]()
    public init() {}
    public mutating func recover(symbol: G.Ctx.State.Symbol) -> Bool {
        guard let savePoint = savePoints[symbol.rawValue] else {
            return false
        }
        self = savePoint
        return true
    }
}

public protocol ParserState<G, Output> {
    associatedtype G : Grammar
    associatedtype Output : ASTNode
    func advance<C : Collection>(_ symb: G.Ctx.State.Symbol?, stream: C, context: inout G.Ctx.State, data: inout IterationData<G, Output>) throws -> Output?  where C.Element == G.Ctx.State.Symbol
    func goto(via rule: String) throws -> any ParserState<G, Output>
}

public struct Sourcegen {
    
    private(set) public var buffer : String
    
    public init(module: String) {
        buffer =
"""
// generated source -- do not touch!
import AST
import \(module)

"""
    }
    
    public mutating func makeSource<G: Grammar, Goal: ASTNode>(_ parser: Parser<G, Goal>, as type: String) {
        
        buffer +=
        
"""
extension \(G.self) {
    public class \(type) : AnyParser {
        public typealias G = \(G.self)
        public typealias Ctx = \(G.Ctx.self)

        \(String(rules(parser).joined(separator: "\n")))

        init(_ grammar: \(G.self)) {
            \(initializer(parser).joined(separator: "\n"))
        }

            public func parse<C : Collection>(_ stream: C) -> Result<\(Goal.self), Errors> where C.Element == \(G.self).Ctx.State.Symbol {
                 
                var iterationData = IterationData<\(G.self), \(Goal.self)>()
                var state = \(G.self).Ctx.State()
                
                iterationData.stateStack.push((state, nil, State0(parser: self)))
                
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
                            guard let st = iterationData.stateStack.peek()?.2 else {
                                throw ASTError.parserDefinition(.undefinedState)
                            }
                            if let node = try st.advance(current, stream: stream, context: &state, data: &iterationData) {
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

        \(String(States(parser: parser, type: type).print().joined(separator: "\n")))
    }
}
"""
        
    }
    
    
    
}

private extension Sourcegen {
    
    func rules<G: Grammar, Goal: ASTNode>(_ parser: Parser<G, Goal>) -> [String] {
        parser.grammar.rules.flatMap {typeName, dict in
            dict.map {ruleName, rule in
"""
let \((typeName + ruleName).asIdentifier) : \(type(of: rule))
"""
            }
        }
    }
    
    func initializer<G: Grammar, Goal: ASTNode>(_ parser: Parser<G, Goal>) -> [String] {
        parser.grammar.rules.flatMap {typeName, dict in
            dict.map {ruleName, rule in
"""
\((typeName + ruleName).asIdentifier) = grammar.rules["\(typeName)"]!["\(ruleName)"]! as! \(type(of: rule))
"""
            }
        }
    }
    
    struct States<G : Grammar, Goal : ASTNode> {
        let parser : Parser<G, Goal>
        let type : String
        func print() -> [String] {
            Set(parser.tables.actions.values.flatMap(\.keys)).union(parser.tables.gotos.values.flatMap(\.keys)).sorted().map {state in
"""
struct State\(state) : ParserState {
typealias G = \(G.self)
typealias Output = \(Goal.self)
var state : Int {\(state)}
    let parser : \(type)
    func advance<C : Collection>(_ symb: G.Ctx.State.Symbol?, stream: C, context: inout G.Ctx.State, data: inout IterationData<G, Output>) throws -> Output? where C.Element == \(G.self).Ctx.State.Symbol {
        \(actions(state: state).joined(separator: "\n"))
        throw ASTError.parserDefinition(.noAction(terminal: symb.map(String.init(describing:)) ?? "", state: \(state)))
    }

    func goto(via rule: String) throws -> any ParserState<G, Output> {
        \(String(gotos(state: state).joined(separator: "\n")))
        throw ASTError.parserDefinition(.noGoto(nonTerminal: rule, state: \(state)))
    }
}
"""
            }
        }
        
        func gotos(state: Int) -> [String] {
            parser.tables.gotos.compactMap {rule, dict in
                guard let target = dict[state] else {return nil}
                return
"""
if rule == "\(rule)" {
    return State\(target)(parser: parser)
}
"""
            }
        }
        
        func actions(state: Int) -> [String] {
            [
"""
guard let rawValue = symb?.rawValue else {
    \(method(state: state, symb: nil))
}
switch rawValue {
"""
            ] +
            parser.tables.actions.filter{$1.keys.contains(state)}.sorted(by: {$0.key.map(String.init(describing:)) ?? "" < $1.key.map(String.init(describing:)) ?? ""}).compactMap {symbol, actions in
                symbol.map {symbol in
"""
case "\(symbol)":
    \(method(state: state, symb: symbol))

"""
                }
            } +
            [
"""
    default:
        ()
}
"""
            ]
        }
        
        func method(state: Int, symb: G.Symbol.RawValue?) -> String {
            parser.tables.actions[symb].flatMap {dict in
                guard let actions = dict[state] else {return nil}
                switch actions {
                case .shift(let next):
                    return
"""
context.advance(symb)
data.stateStack.push((context, symb, State\(next)(parser: parser)))
return nil
"""
                case .reduce(rule: let ruleName, recognized: let meta):
                    return
"""
\(reduce(ruleName, meta).joined(separator: "\n"))
return try data.stateStack.peek()!.2.advance(symb, stream: stream, context: &context, data: &data)
"""
                case .accept:
                    return
"""
return data.stack.peek() as? \(Goal.self)
"""
                }
            } ?? "return nil"
        }
        
        func reduce(_ ruleName: String, _ meta: String) -> [String] {
            let theRule = "parser.\((meta + ruleName).asIdentifier)"
            return reduceChildren(parser.grammar.rules[meta]![ruleName]!, rule: theRule) + [
"""
                    
guard let (oldState, _, stateAfter) = data.stateStack.peek() else {
    throw ASTError.parserDefinition(.undefinedState)
}
let ctx = \(G.self).Ctx.span(from: oldState, to: context, stream: stream)
try data.stack.push(\(theRule).onRecognize(context: ctx))

\(String(flushChildren(parser.grammar.rules[meta]![ruleName]!, rule: theRule).joined(separator: "\n")))
            
let nextState = try stateAfter.goto(via: "\(meta)")
data.stateStack.push((context, symb, nextState))
"""
            ]
        }
        
        func reduceChildren(_ any: Any, rule: String) -> [String] {
            Mirror(reflecting: any).children.reversed().flatMap {label, child in
                
                if child is Injectable {
                    return [
"""
do {
guard let node = data.stack.pop() else {
    throw ASTError.parserDefinition(.undefinedState)
}
try \(rule).$\(label!.dropFirst()).inject(node)
guard nil != data.stateStack.pop() else {
    throw ASTError.parserDefinition(.undefinedState)
}
}
"""
                    ]
                }
                
                else if child is _Terminal<G.Symbol> {
                    return [
"""
do {
guard let (_, char, _) = data.stateStack.pop(), let char = char else {
    throw ASTError.parserDefinition(.undefinedState)
}
try \(rule).$\(label!.dropFirst()).inject(char)
}
"""
                    ]
                }
                return reduceChildren(child, rule: rule)
            }
        }
        
        func flushChildren(_ any: Any, rule: String) -> [String] {
            
            Mirror(reflecting: any).children.flatMap {label, child in
                
                if child is Injectable {
                    return ["\(rule).$\(label!.dropFirst()).flush()"]
                }
                
                return flushChildren(child, rule: rule)
                
            }
            
        }
        
    }
    
}

fileprivate extension String {
    var asIdentifier : String {
        self.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
    }
}
