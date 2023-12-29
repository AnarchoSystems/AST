//
//  TestGrammars.swift
//
//
//  Created by Markus Kasperczyk on 29.12.23.
//

import Foundation
import AST


// MARK: UTILS TESTS

public struct OptionGrammar : Grammar {
    public init() {}
    public  let constructors : [any Constructors<Context>] = [SuccessRules(), Maybe<Letter, Context>(), ARules()]
    
    struct SuccessRules : Constructors {
        typealias Output = Success
        typealias Ctx = Context
        @Case var opt = OptRule()
    }
    
    struct ARules : Constructors {
        typealias Output = Letter
        typealias Ctx = Context
        @Case var a = ARule()
    }
    
}

public struct Success : ASTNode {}

struct OptRule : Constructor {
    @NonTerminal var opt : Letter?
    func onRecognize(context: Context) throws -> Success {
        Success()
    }
}

struct ARule : Constructor {
    @Terminal var a = "A"
    func onRecognize(context: Context) throws -> Letter {
        try Letter(char: a)
    }
}

// MARK: RULES

public struct Rules : Grammar {
    
    public typealias Ctx = AST.Context
    public init() {}
    
    public var constructors : [any Constructors<Ctx>] {idOrInt + identifierRecursion + numberRecursion + lowerLevel}
    
    var lowerLevel : [any Constructors<Ctx>] { digitsOrLetters + letter + digit + oneNine }
    
}

// MARK: ASTNodes

public enum IntOrIdentifier : ASTNode, Equatable {
    case identifier(Identifier)
    case integer(Int)
}

public struct Identifier : ASTNode, Equatable {
    public let string : String
    public init(string: String) {
        self.string = string
    }
}

public struct DigitsOrLetters : ASTNode {
    var string : String
}

public struct DigitOrLetter : ASTNode {
    let char : Character
}

extension Int : ASTNode {
    init(_ oneNine: OneNine, _ digits: [Digit]) throws {
        guard let int = Int(String(oneNine.char) + digits.map(\.char)) else {
            throw NSError()
        }
        self = int
    }
}

public struct Letter : ASTNode {
    let char : Character
    init(char: Character) throws {
        guard char.isLetter else {
            throw NSError()
        }
        self.char = char
    }
}

public struct Digit : ASTNode {
    public let char : Character
    init(char: Character) throws {
        guard let oneNine = Int(String(char)), (0...9).contains(oneNine) else {
            throw NSError()
        }
        self.char = char
    }
}

public struct OneNine : ASTNode {
    let char : Character
    init(char: Character) throws {
        guard let oneNine = Int(String(char)), (1...9).contains(oneNine) else {
            throw NSError()
        }
        self.char = char
    }
}

// MARK: ID OR INT

extension Rules {
    
    var idOrInt : [any Constructors<Ctx>] { [ConstructorList(IdentifierIDOrInt(), IntIDOrInt())] }
    
}

public struct IntIDOrInt : Constructor {
    
    @NonTerminal
    public var int : Int
    
    public func onRecognize(context: Context) throws -> IntOrIdentifier {
        IntOrIdentifier.integer(int)
    }
    
}

public struct IdentifierIDOrInt : Constructor {
    
    @NonTerminal
    public var id : Identifier
    
    public func onRecognize(context: Context) throws -> IntOrIdentifier {
        IntOrIdentifier.identifier(id)
    }
    
}

// MARK: IDENTIFIER

extension Rules {
    
    var identifierRecursion : [any Constructors<Ctx>] { [ConstructorList(LetterIdentifier(), LetterDigitsOrLettersIsIdentifier())] }
    
}

public struct LetterDigitsOrLettersIsIdentifier : Constructor {
    
    @NonTerminal
    public var letter : Letter
    
    @NonTerminal
    public var digitsOrLetters : DigitsOrLetters
    
    public func onRecognize(context: Context) throws -> Identifier {
        return Identifier(string: String(letter.char) + digitsOrLetters.string) // slow...
    }
    
}

public struct LetterIdentifier : Constructor {
    
    @NonTerminal
    public var letter : Letter
    
    public func onRecognize(context: Context) throws -> Identifier {
        Identifier(string: String(letter.char))
    }
    
}

// MARK: DIGITS OR LETTERS

extension Rules {
    
    var digitsOrLetters : [any Constructors<Ctx>] { [ConstructorList(DigitsOrLettersRecursion(), DigitOrLetterIsDigitsOrLetters()), ConstructorList(LetterIsDigitOrLetter(),DigitIsDigitOrLetter())] }
    
}

public struct DigitsOrLettersRecursion : Constructor {
    
    @NonTerminal
    public var known : DigitsOrLetters
    
    @NonTerminal
    public var new : DigitOrLetter
    
    public func onRecognize(context: Context) throws -> DigitsOrLetters {
        known.string.append(new.char)
        return known
    }
    
}

public struct DigitOrLetterIsDigitsOrLetters : Constructor {
    
    @NonTerminal
    public var digitOrLetter : DigitOrLetter
    
    public func onRecognize(context: Context) throws -> DigitsOrLetters {
        DigitsOrLetters(string: String(digitOrLetter.char))
    }
    
}

public struct LetterIsDigitOrLetter : Constructor {
    
    @NonTerminal public var letter : Letter
    
    public func onRecognize(context: Context) throws -> DigitOrLetter {
        DigitOrLetter(char: letter.char)
    }
    
}

public struct DigitIsDigitOrLetter : Constructor {
    
    @NonTerminal public var digit : Digit
    
    public func onRecognize(context: Context) throws -> DigitOrLetter {
        DigitOrLetter(char: digit.char)
    }
    
}

// MARK: NUMBER

extension Rules {
    
    var numberRecursion : [any Constructors<Ctx>] { [NonEmptyListRecognizer<Digit, Ctx>(), ConstructorList(NumberRecognizer())] }
    
}

public struct NumberRecognizer : Constructor {
    
    @NonTerminal public var oneNine : OneNine
    @NonTerminal public var digits : [Digit]
    
    public func onRecognize(context: Context) throws ->  Int {
        try Int(oneNine, digits)
    }
    
}

// MARK: LETTER

extension Rules {
    
    var letter : [any Constructors<Ctx>] { [LetterRules()] }
    
    struct LetterRules : Constructors {
        typealias Ctx = Context
        typealias Output = Letter
        var allConstructors: [any Constructor<Rules.Ctx, Letter>] {
            ["a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F", "g", "G", "h", "H", "i", "I", "j", "J",
                                       "k", "K", "l", "L", "m", "M", "n", "N", "o", "O", "p", "P", "q", "Q", "r", "R", "s", "S", "t", "T", "u", "U", "v", "V",
                                       "w", "W", "x", "X", "y", "Y", "z", "Z"].map(LetterRecognizer.init)
        }
    }
    
}

public struct LetterRecognizer : Constructor {
    
    public var ruleName: String {
        "Letter \(char)"
    }
    
    @Terminal public var char : Character
    
    public func onRecognize(context: Context) throws -> Letter {
        try Letter(char: char)
    }
    
}

// MARK: DIGIT

extension Rules {
    
    var digit : [any Constructors<Ctx>] { [DigitRules()] }
    
    struct DigitRules : Constructors {
        typealias Ctx = Context
        typealias Output = Digit
        var allConstructors: [any Constructor<Rules.Ctx, Digit>] {
            (0...9).map(String.init).compactMap(\.first).map(DigitRecognizer.init)
        }
    }
    
}

public struct DigitRecognizer : Constructor {
    
    public var ruleName: String {
        "Digit \(char)"
    }
    
    @Terminal public var char : Character
    
    public func onRecognize(context: Context) throws -> Digit {
        try Digit(char: char)
    }
    
}

// MARK: ONE-NINE

extension Rules {
    
    var oneNine : [any Constructors<Ctx>] { [OneNineRules()] }
    
    struct OneNineRules : Constructors {
        typealias Ctx = Context
        typealias Output = OneNine
        var allConstructors: [any Constructor<Ctx, OneNine>] {
            (1...9).map(String.init).compactMap(\.first).map(OneNineRecognizer.init)
        }
    }
    
}

public struct OneNineRecognizer : Constructor {
    
    public var ruleName: String {
        "OneNine \(char)"
    }
    
    @Terminal public var char : Character
    
    public func onRecognize(context: Context) throws -> OneNine {
        try OneNine(char: char)
    }
    
}

// MARK: List Nodes

public struct Expression : ASTNode {
    public  let char : Character
}

public struct CommaSeparatedexpressions : ASTNode {
    public var exprs : [Expression]
}

// MARK: List Rules

public struct RecNextIsList : Constructor {
    
    @NonTerminal
    public var recognized : CommaSeparatedexpressions
    
    @Terminal public var separator = ","
    
    @NonTerminal
    public var next : Expression
    
    public func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        recognized.exprs.append(next)
        return recognized
    }
    
}

public struct EmptyIsList : Constructor {
    
    public func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        CommaSeparatedexpressions(exprs: [])
    }
    
}

public struct ExprIsList : Constructor {
    
    @NonTerminal
    public var expr : Expression
    
    public func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        CommaSeparatedexpressions(exprs: [expr])
    }
    
}

public struct CharIsExpr : Constructor {
    
    public var ruleName: String {
        "Char \(char)"
    }
    
    @Terminal public var char : Character
    
    public func onRecognize(context: Context) throws -> Expression {
        Expression(char: char)
    }
    
}

// MARK: List Grammar

public struct ListGrammar : Grammar {
    public init() {}
    public var constructors: [any Constructors<Context>] {
        [ExprRules(), ListRules()]
    }
    struct ExprRules : Constructors {
        typealias Output = Expression
        typealias Ctx = Context
        @Case var a = CharIsExpr(char: "a")
        @Case var b = CharIsExpr(char: "b")
        @Case var c = CharIsExpr(char: "c")
    }
    struct ListRules : Constructors {
        typealias Output = CommaSeparatedexpressions
        typealias Ctx = Context
        @Case var recursion = RecNextIsList()
        @Case var empty = EmptyIsList()
        @Case var expr = ExprIsList()
    }
}

