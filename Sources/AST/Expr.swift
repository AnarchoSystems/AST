//
//  Expr.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public enum Expr<Symbol : Hashable> : Hashable {
    case eof
    case term(Symbol)
    case nonTerm(String)
}
