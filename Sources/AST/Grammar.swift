//
//  Grammar.swift
//
//
//  Created by Markus Kasperczyk on 31.10.23.
//

public protocol Grammar {
    var allRules : [any Rule] {get}
    init()
}

public extension Grammar {
    var rules : [String : [String : any Rule]] {
        Dictionary(allRules.map{rule in
            return (rule.typeName, [rule.ruleName : rule])
        }) {dict1, dict2 in dict1.merging(dict2) {_, _ in fatalError()}}
    }
    var allExprs : Set<Expr> {
        var results = Set<Expr>()
        for type in rules.values {
            for rule in type.values {
                results.formUnion(Mirror(reflecting: rule).children.compactMap{($1 as? ExprProperty)?.expr})
            }
        }
        return results
    }
}
