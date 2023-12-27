//
//  Grammar.swift
//
//
//  Created by Markus Kasperczyk on 31.10.23.
//

public protocol Grammar {
    associatedtype Context : ContextProtocol
    var allRules : [any Rule<Context>] {get}
}

public extension Grammar {
    typealias Symbol = Context.State.Symbol
    var rules : [String : [String : any Rule]] {
        Dictionary(allRules.map{rule in
            return (rule.typeName, [rule.ruleName : rule])
        }) {dict1, dict2 in dict1.merging(dict2) {_, _ in fatalError()}}
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
