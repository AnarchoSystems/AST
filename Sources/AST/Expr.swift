//
//  Expr.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public enum Expr : Hashable {
    case eof
    case term(Character)
    case nonTerm(String)
}
