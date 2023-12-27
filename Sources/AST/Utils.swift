//
//  Utils.swift
//
//
//  Created by Markus Kasperczyk on 27.12.23.
//

extension Optional : ASTNode where Wrapped : ASTNode {}

public struct MakeOptional<N : ASTNode, Ctx : ContextProtocol> : Rule {
    
    public var ruleName: String {
        "optional \(N.typeDescription)"
    }
    
    @NonTerminal var node : N
    
    public func onRecognize(context: Ctx) throws -> some ASTNode {
        Optional.some(node)
    }
    
    public init() {}
    
}

public struct Zero<N : ASTNode, Ctx : ContextProtocol> : Rule {
    
    public var ruleName: String {
        "zero \(N.typeDescription)"
    }
    
    public func onRecognize(context: Ctx) throws -> some ASTNode {
        Optional<N>.none
    }
    
    public init() {}
    
}

extension Array : ASTNode where Element : ASTNode {}

public struct EmptyList<N : ASTNode, Ctx : ContextProtocol> : Rule {
    public func onRecognize(context: Ctx) throws -> some ASTNode {
        [N]()
    }
    public init() {}
}

public struct FirstElem<N : ASTNode, Ctx : ContextProtocol> : Rule {
    @NonTerminal var node : N
    public func onRecognize(context: Ctx) throws -> some ASTNode {
        [node]
    }
    public init() {}
}

public struct Repeat<N: ASTNode, Ctx : ContextProtocol> : Rule {
    @NonTerminal var list : [N]
    @NonTerminal var next : N
    public func onRecognize(context: Ctx) throws -> some ASTNode {
        list.append(next)
        return list
    }
    public init() {}
}
