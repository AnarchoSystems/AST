//
//  PropertyWrappers.swift
//
//
//  Created by Markus Kasperczyk on 28.12.23.
//

// MARK: Property Wrappers

public protocol ExprProperty<Symbol> {
    associatedtype Symbol : Hashable
    var expr : Expr<Symbol> {get}
}

public protocol Injectable {
    func inject(_ any: Any) throws
    func flush()
}

public protocol HasTypeName {
    var typeName : String {get}
}

@propertyWrapper
public final class _NonTerminal<Symbol : SymbolProtocol, Meta : ASTNode> : ExprProperty, Injectable, HasTypeName {
    public var typeName: String {
        Meta.typeDescription
    }
    var wrapped : Meta?
    public func inject(_ any: Any) throws {
        do {
            guard let meta = any as? Meta else {
                throw ASTError.parserRuntime(.stackCorrupted(popped: any, expecting: String(describing: type(of: any).self)))
            }
            wrapped = meta
        }
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
    public func flush() {
        wrapped = nil
    }
    public var projectedValue : _NonTerminal<Symbol, Meta> {self}
    public init() {}
    public var expr: Expr<Symbol.RawValue> {
        .nonTerm(typeName)
    }
}

@propertyWrapper
public final class _Terminal<Symbol : SymbolProtocol> : ExprProperty {
    public let checkSymbol : Symbol.RawValue
    var wrapped : Symbol?
    public func inject(_ symb: Symbol) throws {
        guard symb.rawValue == checkSymbol else {
            throw ASTError.parserRuntime(.stackCorrupted(popped: symb, expecting: String(describing: checkSymbol)))
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
    public var projectedValue : _Terminal<Symbol> {self}
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

public extension Constructor {
    typealias NonTerminal<Meta : ASTNode> = _NonTerminal<Context.State.Symbol, Meta>
    typealias Terminal = _Terminal<Context.State.Symbol>
}

protocol CaseProtocol<Ctx, MetaType> {
    associatedtype Ctx : ContextProtocol
    associatedtype MetaType : ASTNode
    var constructor : any Constructor<Ctx, MetaType> {get}
}

@propertyWrapper
public struct _Case<R : Constructor> : CaseProtocol {
    typealias Ctx = R.Ctx
    typealias MetaType = R.MetaType
    public let wrappedValue : R
    public init(wrappedValue: R) {
        self.wrappedValue = wrappedValue
    }
    var constructor: any Constructor<R.Ctx, R.MetaType> {
        wrappedValue
    }
}

public extension Constructors {
    typealias Case<R : Constructor> = _Case<R> where R.MetaType == Output, R.Ctx == Ctx
    var allConstructors : [any Constructor<Ctx, Output>] {
        Mirror(reflecting: self).children.compactMap{($1 as? any CaseProtocol<Ctx, Output>)?.constructor}
    }
}

public struct ConstructorList<Output : ASTNode, Ctx : ContextProtocol> : Constructors {
    public let allConstructors: [any Constructor<Ctx, Output>]
    public init(_ allConstructors: [any Constructor<Ctx, Output>]) {
        self.allConstructors = allConstructors
    }
    public init(_ constructors: (any Constructor<Ctx, Output>)...) {
        self = .init(constructors)
    }
}
