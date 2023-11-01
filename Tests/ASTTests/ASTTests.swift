import XCTest
@testable import AST

final class ASTTests: XCTestCase {
    func testExample() throws {
        
        let parser = try Parser.CLR1(rules: Rules<IntOrIdentifier>.self)
        
        let num = 134890024502403
        try XCTAssertEqual(parser.parse("\(num)"), .integer(num))
        
        XCTAssertThrowsError(try parser.parse("1203240a"))
        
        let str = "a2450236taAFwegaeF005389"
        try XCTAssertEqual(parser.parse(str), .identifier(Identifier(string: str)))
        
    }
}

// MARK: RULES

struct Rules<Goal : ASTNode> : RuleCollection {
    
    static var allRules: [Factory] { idOrInt + identifierRecursion + numberRecursion + digitsOrLetters + letter + digit + oneNine }
    
}

// MARK: ASTNodes

enum IntOrIdentifier : ASTNode, Equatable {
    case identifier(Identifier)
    case integer(Int)
}

struct Identifier : ASTNode, Equatable {
    let string : String
}

struct DigitsOrLetters : ASTNode {
    var string : String
}

struct DigitOrLetter : ASTNode {
    let char : Character
}

extension Int : ASTNode {
    init(_ oneNine: OneNine, _ digits: Digits) throws {
        guard let int = Int(String(oneNine.char) + digits.digits.map(\.char)) else {
            throw NSError()
        }
        self = int
    }
}

struct Digits : ASTNode {
    var digits : [Digit]
    init(digit: Digit) {
        self.digits = [digit]
    }
    init(digits: inout Digits, newDigit: Digit) {
        digits.digits.append(newDigit)
        self = digits
    }
}

struct Letter : ASTNode {
    let char : Character
    init(char: Character) throws {
        guard char.isLetter else {
            throw NSError()
        }
        self.char = char
    }
}

struct Digit : ASTNode {
    let char : Character
    init(char: Character) throws {
        guard let oneNine = Int(String(char)), (0...9).contains(oneNine) else {
            throw NSError()
        }
        self.char = char
    }
}

struct OneNine : ASTNode {
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
    
    static var idOrInt : [Factory] { [IdentifierIDOrInt.init, IntIDOrInt.init] }
    
}

struct IntIDOrInt : Rule {
    
    @NonTerminal
    var int : Int
    
    func onRecognize() throws -> some ASTNode {
        IntOrIdentifier.integer(int)
    }
    
}

struct IdentifierIDOrInt : Rule {
    
    @NonTerminal
    var id : Identifier
    
    func onRecognize() throws -> some ASTNode {
        IntOrIdentifier.identifier(id)
    }
    
}

// MARK: IDENTIFIER

extension Rules {
    
    static var identifierRecursion : [Factory] { [LetterIdentifier.init, LetterDigitsOrLettersIsIdentifier.init] }
    
}

struct LetterDigitsOrLettersIsIdentifier : Rule {
    
    @NonTerminal
    var letter : Letter
    
    @NonTerminal
    var digitsOrLetters : DigitsOrLetters
    
    func onRecognize() throws -> some ASTNode {
        return Identifier(string: String(letter.char) + digitsOrLetters.string) // slow...
    }
    
}

struct LetterIdentifier : Rule {
    
    @NonTerminal
    var letter : Letter
    
    func onRecognize() throws -> some ASTNode {
        Identifier(string: String(letter.char))
    }
    
}

// MARK: DIGITS OR LETTERS

extension Rules {
    
    static var digitsOrLetters : [Factory] {[DigitsOrLettersRecursion.init, DigitIsDigitOrLetter.init, LetterIsDigitOrLetter.init, DigitOrLetterIsDigitsOrLetters.init]}
    
}

struct DigitsOrLettersRecursion : Rule {
    
    @NonTerminal
    var known : DigitsOrLetters
    
    @NonTerminal
    var new : DigitOrLetter
    
    func onRecognize() throws -> some ASTNode {
        known.string.append(new.char)
        return known
    }
    
}

struct DigitOrLetterIsDigitsOrLetters : Rule {
    
    @NonTerminal
    var digitOrLetter : DigitOrLetter
    
    func onRecognize() throws -> some ASTNode {
        DigitsOrLetters(string: String(digitOrLetter.char))
    }
    
}

struct LetterIsDigitOrLetter : Rule {
    
    @NonTerminal var letter : Letter
    
    func onRecognize() throws -> some ASTNode {
        DigitOrLetter(char: letter.char)
    }
    
}

struct DigitIsDigitOrLetter : Rule {
    
    @NonTerminal var digit : Digit
    
    func onRecognize() throws -> some ASTNode {
        DigitOrLetter(char: digit.char)
    }
    
}

// MARK: NUMBER

extension Rules {
    
    static var numberRecursion : [Factory] { [DigitDigits.init, DigitDigitsDigits.init, NumberRecognizer.init] }
    
}

struct NumberRecognizer : Rule {
    
    @NonTerminal var oneNine : OneNine
    @NonTerminal var digits : Digits
    
    func onRecognize() throws ->  some ASTNode {
        try Int(oneNine, digits)
    }
    
}

struct DigitDigitsDigits : Rule {
    
    @NonTerminal var digits : Digits
    @NonTerminal var digit : Digit
    
    func onRecognize() throws ->  some ASTNode {
        Digits(digits: &digits, newDigit: digit)
    }
    
}

struct DigitDigits : Rule {
    
    @NonTerminal var digit : Digit
    
    func onRecognize() throws ->  some ASTNode {
        Digits(digit: digit)
    }
    
}

// MARK: LETTER

extension Rules {
    
    static var letter : [Factory] { ["a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F", "g", "G", "h", "H", "i", "I", "j", "J",
                                     "k", "K", "l", "L", "m", "M", "n", "N", "o", "O", "p", "P", "q", "Q", "r", "R", "s", "S", "t", "T", "u", "U", "v", "V",
                                     "w", "W", "x", "X", "y", "Y", "z", "Z"].map{char in {LetterRecognizer(char: char)}}}
    
}

struct LetterRecognizer : Rule {
    
    var ruleName: String {
        "Letter \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize() throws ->  some ASTNode {
        try Letter(char: char)
    }
    
}

// MARK: DIGIT

extension Rules {
    
    static var digit : [Factory] { (0...9).map(String.init).compactMap(\.first).map{char in {DigitRecognizer(char: char)}} as [Factory] }
    
}

struct DigitRecognizer : Rule {
    
    var ruleName: String {
        "Digit \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize() throws ->  some ASTNode {
        try Digit(char: char)
    }
    
}

// MARK: ONE-NINE

extension Rules {
    
    static var oneNine : [Factory] { (1...9).map(String.init).compactMap(\.first).map{char in {OneNineRecognizer(char: char)}} as [Factory] }
    
}

struct OneNineRecognizer : Rule {
    
    var ruleName: String {
        "OneNine \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize() throws -> some ASTNode {
        try OneNine(char: char)
    }
    
}
