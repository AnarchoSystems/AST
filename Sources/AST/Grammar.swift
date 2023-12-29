//
//  Grammar.swift
//
//
//  Created by Markus Kasperczyk on 31.10.23.
//

public protocol Grammar {
    associatedtype Ctx : ContextProtocol
    var constructors : [any Constructors<Ctx>] {get}
    var savePoints : Set<Ctx.State.Symbol.RawValue> {get}
}

public extension Grammar {
    var savePoints : Set<Ctx.State.Symbol.RawValue> {[]}
}

public extension Constructors {
    var erasedConstructors : [any Rule<Ctx>] {
        allConstructors as [any Rule<Ctx>]
    }
}

public extension Grammar {
    typealias Symbol = Ctx.State.Symbol
    var rules : [String : [String : any Rule<Ctx>]] {
        var rules = [(String, [String : any Rule<Ctx>])]()
        for constructor in constructors {
            for rule in constructor.erasedConstructors {
                rules.append((rule.typeName, [rule.ruleName : rule as any Rule<Ctx>]))
            }
        }
        var result = [String : [String : any Rule<Ctx>]]()
        for (name, dict) in rules {
            if result[name] == nil {
                result[name] = dict
            }
            else {
                result[name]?.merge(dict, uniquingKeysWith: {fatalError("Rule \($1.ruleName) is multiply defined!")})
            }
        }
        return result
    }
    var allExprs : Set<Expr<Symbol.RawValue>> {
        var results = Set<Expr<Symbol.RawValue>>()
        for type in rules.values {
            for rule in type.values {
                results.formUnion(Mirror(reflecting: rule).children.compactMap{($1 as? any ExprProperty<Symbol.RawValue>)?.expr})
            }
        }
        return results
    }
}
