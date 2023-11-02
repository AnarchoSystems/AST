//
//  File.swift
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

public protocol ASTNode {
    static var typeDescription : String {get}
}

public extension ASTNode {
    static var typeDescription : String {
        String(describing: Self.self)
    }
}

public protocol Rule<MetaType> {
    var ruleName : String {get}
    associatedtype MetaType : ASTNode
    func onRecognize() throws -> MetaType
}

public extension Rule {
    var ruleName : String {
        String(describing: Self.self)
    }
    var typeName : String {
        MetaType.typeDescription
    }
}

public protocol Injectable {
    var typeName : String {get}
    func inject(_ any: Any) throws
}

public protocol ExprProperty {
    var expr : Expr {get}
}

public struct UnexpectedType : Error {
    public let given : Any
    public let expected : Any.Type
}

@propertyWrapper
public class NonTerminal<Meta : ASTNode> : ExprProperty, Injectable {
    public var typeName: String {
        Meta.typeDescription
    }
    var wrapped : Meta?
    public func inject(_ any: Any) throws {
        guard let meta = any as? Meta else {
            throw UnexpectedType(given: any, expected: Meta.self)
        }
        wrapped = meta
    }
    public var wrappedValue : Meta {
        get
        {
            wrapped!
        }
        set
        {
            wrapped = newValue
        }
    }
    public init() {}
    public var expr: Expr {
        .nonTerm(typeName)
    }
}

@propertyWrapper
public struct Terminal : ExprProperty {
    public let wrappedValue : Character
    public init(wrappedValue: Character) {
        self.wrappedValue = wrappedValue
    }
    public var expr: Expr {
        .term(wrappedValue)
    }
}
