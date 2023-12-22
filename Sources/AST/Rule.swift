//
//  Rule.swift
//  
//
//  Created by Markus Kasperczyk on 02.11.23.
//

public protocol Rule<Context> {
    associatedtype Context : ContextProtocol
    var ruleName : String {get}
    associatedtype MetaType : ASTNode
    func onRecognize(context: Context) throws -> MetaType
}

extension Rule {
    func _onRecognize(_ any: Any) throws -> MetaType {
        try onRecognize(context: any as! Context)
    }
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

public protocol ExprProperty<Symbol> {
    associatedtype Symbol : Hashable
    var expr : Expr<Symbol> {get}
}

public protocol Injectable {
    func inject(_ any: Any) throws
}

public protocol HasTypeName {
    var typeName : String {get}
}

@propertyWrapper
public class _NonTerminal<Symbol : SymbolProtocol, Meta : ASTNode> : ExprProperty, Injectable, HasTypeName {
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
    public var expr: Expr<Symbol.RawValue> {
        .nonTerm(typeName)
    }
}

@propertyWrapper
public class _Terminal<Symbol : SymbolProtocol> : ExprProperty {
    public let checkSymbol : Symbol.RawValue
    var wrapped : Symbol?
    public func inject(_ symb: Symbol) throws {
        guard symb.rawValue == checkSymbol else {
            throw UnexpectedSymbol(got: symb, expected: checkSymbol)
        }
        wrapped = symb
    }
    public var wrappedValue : Symbol {
        _read
        {
            yield wrapped!
        }
        _modify
        {
           yield &wrapped!
        }
    }
    public init(_ check: Symbol.RawValue) {
        self.checkSymbol = check
    }
    public init(wrappedValue: Symbol) where Symbol.RawValue == Symbol {
        self.checkSymbol = wrappedValue
        self.wrapped = wrappedValue
    }
    public var expr: Expr<Symbol.RawValue> {
        .term(checkSymbol)
    }
}

public extension Rule {
    typealias NonTerminal<Meta : ASTNode> = _NonTerminal<Context.State.Symbol, Meta>
    typealias Terminal = _Terminal<Context.State.Symbol>
}

