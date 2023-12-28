//
//  Utils.swift
//
//
//  Created by Markus Kasperczyk on 27.12.23.
//

extension Optional : ASTNode where Wrapped : ASTNode {}

public struct Maybe<N : ASTNode, Ctx : ContextProtocol> : Constructors {
    public typealias Output = N?
    @Case var some = Some<N, Ctx>()
    @Case var none = None<N, Ctx>()
    public init() {}
}

public struct Some<N : ASTNode, Ctx : ContextProtocol> : Constructor {
    
    public var ruleName: String {
        "some \(N.typeDescription)"
    }
    
    @NonTerminal var node : N
    
    public func onRecognize(context: Ctx) throws -> N? {
        Optional.some(node)
    }
    
    public init() {}
    
}

public struct None<N : ASTNode, Ctx : ContextProtocol> : Constructor {
    
    public var ruleName: String {
        "none \(N.typeDescription)"
    }
    
    public func onRecognize(context: Ctx) throws -> N? {
        Optional<N>.none
    }
    
    public init() {}
    
}

extension Array : ASTNode where Element : ASTNode {}

public struct ListRecognizer<Meta : ASTNode, Ctx : ContextProtocol> : Constructors {
    public typealias Output = [Meta]
    @Case var empty = EmptyList<Meta, Ctx>()
    @Case var repetition = Repeat<Meta, Ctx>()
    public init() {}
}

public struct NonEmptyListRecognizer<Meta : ASTNode, Context : ContextProtocol> : Constructors {
    public typealias Output = [Meta]
    public typealias Ctx = Context
    @Case var empty = FirstElem<Meta, Ctx>()
    @Case var repetition = Repeat<Meta, Ctx>()
    public init() {}
}

public struct EmptyList<N : ASTNode, Ctx : ContextProtocol> : Constructor {
    public var ruleName: String {
        "empty list of \(N.typeDescription)"
    }
    public func onRecognize(context: Ctx) throws -> [N] {
        [N]()
    }
    public init() {}
}

public struct FirstElem<N : ASTNode, Ctx : ContextProtocol> : Constructor {
    public var ruleName: String {
        "first element of \(N.typeDescription)"
    }
    @NonTerminal var node : N
    public func onRecognize(context: Ctx) throws -> [N] {
        [node]
    }
    public init() {}
}

public struct Repeat<N: ASTNode, Ctx : ContextProtocol> : Constructor {
    public var ruleName: String {
        "repetition of \(N.typeDescription)"
    }
    @NonTerminal var list : [N]
    @NonTerminal var next : N
    public func onRecognize(context: Ctx) throws -> [N] {
        list.append(next)
        return list
    }
    public init() {}
}
