//
//  Errors.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public struct ShiftReduceConflict : Error {}

public struct AcceptConflict : Error {}

public struct UndefinedState<Index> : Error {
    let position : Index
}

public struct UnexpectedChar<Symbol> : Error {
    public let char : Symbol?
    public let expecting : Set<String>
}

public struct InvalidChar<Index, Symbol> : Error {
    public let position : Index
    public let char : Symbol?
}

public struct NoGoTo : Error {
    public let nonTerm : String
    public let state : Int
}

public struct ReduceReduceConflict : Error {
    public let meta1 : String
    public let meta2 : String
    public let rule1 : String
    public let rule2 : String
}

public struct UnknownRule : Error {
    public let metaType : String
    public let rule : String
}

public struct ParserDefinitionError : Error {
    public let goal : String
    public let kind : Kind
    public enum Kind {
        case notDefined
        case multiplyDefined
    }
}

public struct UnexpectedType : Error {
    public let given : Any
    public let expected : Any.Type
}

public struct UnexpectedSymbol<Symb : SymbolProtocol> : Error {
    public let got : Symb
    public let expected : Symb.RawValue
}
