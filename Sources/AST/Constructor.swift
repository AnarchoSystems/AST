//
//  Rule.swift
//  
//
//  Created by Markus Kasperczyk on 02.11.23.
//

public protocol Rule<Ctx> {
    associatedtype Ctx : ContextProtocol
    var ruleName : String {get}
    associatedtype MetaType : ASTNode
    func onRecognize(context: Ctx) throws -> MetaType
}

extension Rule {
    func _onRecognize(any: Any) throws -> MetaType {
        try onRecognize(context: any as! Ctx)
    }
}

public protocol Constructor<Ctx, MetaType> : Rule {
    associatedtype Ctx
    associatedtype MetaType
    func onRecognize(context: Ctx) throws -> MetaType
}

extension Constructor {
    func _onRecognize(_ any: Any) throws -> MetaType {
        try onRecognize(context: any as! Ctx)
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

public protocol Constructors<Ctx> {
    associatedtype Ctx : ContextProtocol
    associatedtype Output : ASTNode
    var allConstructors : [any Constructor<Ctx, Output>] {get}
}
