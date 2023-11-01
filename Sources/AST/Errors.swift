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
    let position : String.Index
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
