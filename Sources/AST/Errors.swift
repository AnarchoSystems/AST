//
//  Errors.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public struct ShiftReduceConflict : Error {}

public struct AcceptConflict : Error {}

public struct UndefinedState : Error {
    let position : String.Index
}

public struct UnexpectedChar : Error {
    public let char : Character?
    public let expecting : Set<String>
}

public struct InvalidChar : Error {
    public let position : String.Index
    public let char : Character
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
