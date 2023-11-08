//
//  Rule.swift
//  
//
//  Created by Markus Kasperczyk on 02.11.23.
//

public protocol Rule {
    var ruleName : String {get}
    associatedtype MetaType : ASTNode
    func onRecognize(in range: ClosedRange<String.Index>, context: Context) throws -> MetaType
}

public extension Rule {
    var ruleName : String {
        String(describing: Self.self)
    }
    var typeName : String {
        MetaType.typeDescription
    }
}

// MARK: Property Wrappers

public protocol ExprProperty {
    var expr : Expr {get}
}

public protocol Injectable {
    var typeName : String {get}
    func inject(_ any: Any) throws
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
        _read
        {
            yield wrapped!
        }
        _modify
        {
           yield &wrapped!
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
