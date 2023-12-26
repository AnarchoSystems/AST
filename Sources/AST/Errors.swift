//
//  Errors.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public enum ASTError : Error {
    case parserGeneration(ParserGenerationError)
    case parserDefinition(ParserDefinitionError)
    case parserRuntime(ParserRuntimeError)
}

public enum ParserGenerationError {
    case shiftReduceConflict
    case reduceReduceConflict(meta1: String, meta2: String, rule1: String, rule2: String)
    case acceptConflict
}

public enum ParserDefinitionError {
    case undefinedState
    case noGoto(nonTerminal: String, state: Int)
    case noAction(terminal: String, state: Int)
    case unknownRule(metaType: String, rule: String)
}

public enum ParserRuntimeError {
    case unexpectedSymbol(String, expecting: [String])
    case stackCorrupted(popped: Any, expecting: String)
}
