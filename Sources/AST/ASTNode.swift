//
//  ASTNode.swift
//  
//
//  Created by Markus Kasperczyk on 02.11.23.
//

public protocol ASTNode {
    static var typeDescription : String {get}
}

public extension ASTNode {
    static var typeDescription : String {
        String(describing: Self.self)
    }
}
