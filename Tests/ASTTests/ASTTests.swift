import XCTest
import AST

final class ASTTests: XCTestCase {
    
    func testIdOrInt() throws {
        
        let parser = try Parser.CLR1(rules: Rules.self, goal: IntOrIdentifier.self)
        
        let num = 134890024502403
        try XCTAssertEqual(parser.parse("\(num)"), .integer(num))
        
        XCTAssertThrowsError(try parser.parse("1203240a"))
        
        let str = "a2450236taAFwegaeF005389"
        try XCTAssertEqual(parser.parse(str), .identifier(Identifier(string: str)))
        
    }
    
    func testInt() throws {
        
        let parser = try Parser.CLR1(rules: Rules.self, goal: Int.self)
        
        for num in [124050, 130480, 300950480, 1023840209, 38239840831049804, 190480948] {
            
            try XCTAssertEqual(parser.parse("\(num)"), num)
            
        }
        
    }
    
    func testIdentifier() throws {
        
        let parser = try Parser.CLR1(rules: Rules.self, goal: Identifier.self)
        
        for str in ["a1253ga325346", "efaghlkhgklnalrk", "AFEALFKHafhs", "ohIAEFho2345sfdh"] {
            try XCTAssertEqual(parser.parse(str), Identifier(string: str))
        }
        
        for str in ["12hai", "2aeugho", "3LHafNA3"] {
            XCTAssertThrowsError(try parser.parse(str))
        }
        
    }
    
    func testDigit() throws {
        
        let parser = try Parser.CLR1(rules: Rules.self, goal: Digit.self)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(parser)
        
        print(String(data: data, encoding: .utf8)!)
        
        let newParser = try JSONDecoder().decode(Parser<Rules, Digit>.self, from: data)
        
        XCTAssertEqual(parser, newParser)
        
    }
    
    func testList() throws {
        
        let parser = try Parser.CLR1(rules: ListGrammar.self, goal: CommaSeparatedexpressions.self)
        
        try XCTAssertEqual(parser.parse("a,b,a")?.exprs.map(\.char), ["a", "b", "a"])
        
    }
    
    func testPerformance() throws {
        
        let parser = try Parser.CLR1(rules: Rules.self, goal: IntOrIdentifier.self)
        
        measure {
            do {
                let num = 134890024502403
                _ = try parser.parse("\(num)")
            }
            catch {
                XCTFail()
            }
        }
        
    }
    
}

// MARK: RULES

struct Rules : Grammar {
    
    typealias Context = AST.Context
    
    var allRules : [any Rule<Context>] { idOrInt + identifierRecursion + numberRecursion + lowerLevel}
    
    var lowerLevel : [any Rule<Context>] { digitsOrLetters + letter + digit + oneNine }
    
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
    
    var idOrInt : [any Rule<Context>] { [IdentifierIDOrInt(), IntIDOrInt()] }
    
}

struct IntIDOrInt : Rule {
    
    @NonTerminal
    var int : Int
    
    func onRecognize(context: Context) throws -> some ASTNode {
        IntOrIdentifier.integer(int)
    }
    
}

struct IdentifierIDOrInt : Rule {
    
    @NonTerminal
    var id : Identifier
    
    func onRecognize(context: Context) throws -> some ASTNode {
        IntOrIdentifier.identifier(id)
    }
    
}

// MARK: IDENTIFIER

extension Rules {
    
    var identifierRecursion : [any Rule<Context>] { [LetterIdentifier(), LetterDigitsOrLettersIsIdentifier()] }
    
}

struct LetterDigitsOrLettersIsIdentifier : Rule {
    
    @NonTerminal
    var letter : Letter
    
    @NonTerminal
    var digitsOrLetters : DigitsOrLetters
    
    func onRecognize(context: Context) throws -> some ASTNode {
        return Identifier(string: String(letter.char) + digitsOrLetters.string) // slow...
    }
    
}

struct LetterIdentifier : Rule {
    
    @NonTerminal
    var letter : Letter
    
    func onRecognize(context: Context) throws -> some ASTNode {
        Identifier(string: String(letter.char))
    }
    
}

// MARK: DIGITS OR LETTERS

extension Rules {
    
    var digitsOrLetters : [any Rule<Context>] { [DigitsOrLettersRecursion(), DigitIsDigitOrLetter(), LetterIsDigitOrLetter(), DigitOrLetterIsDigitsOrLetters()] }
    
}

struct DigitsOrLettersRecursion : Rule {
    
    @NonTerminal
    var known : DigitsOrLetters
    
    @NonTerminal
    var new : DigitOrLetter
    
    func onRecognize(context: Context) throws -> some ASTNode {
        known.string.append(new.char)
        return known
    }
    
}

struct DigitOrLetterIsDigitsOrLetters : Rule {
    
    @NonTerminal
    var digitOrLetter : DigitOrLetter
    
    func onRecognize(context: Context) throws -> some ASTNode {
        DigitsOrLetters(string: String(digitOrLetter.char))
    }
    
}

struct LetterIsDigitOrLetter : Rule {
    
    @NonTerminal var letter : Letter
    
    func onRecognize(context: Context) throws -> some ASTNode {
        DigitOrLetter(char: letter.char)
    }
    
}

struct DigitIsDigitOrLetter : Rule {
    
    @NonTerminal var digit : Digit
    
    func onRecognize(context: Context) throws -> some ASTNode {
        DigitOrLetter(char: digit.char)
    }
    
}

// MARK: NUMBER

extension Rules {
    
    var numberRecursion : [any Rule<Context>] { [DigitDigits(), DigitDigitsDigits(), NumberRecognizer()] }
    
}

struct NumberRecognizer : Rule {
    
    @NonTerminal var oneNine : OneNine
    @NonTerminal var digits : Digits
    
    func onRecognize(context: Context) throws ->  Int {
        try Int(oneNine, digits)
    }
    
}

struct DigitDigitsDigits : Rule {
    
    @NonTerminal var digits : Digits
    @NonTerminal var digit : Digit
    
    func onRecognize(context: Context) throws ->  some ASTNode {
        Digits(digits: &digits, newDigit: digit)
    }
    
}

struct DigitDigits : Rule {
    
    @NonTerminal var digit : Digit
    
    func onRecognize(context: Context) throws ->  some ASTNode {
        Digits(digit: digit)
    }
    
}

// MARK: LETTER

extension Rules {
    
    var letter : [any Rule<Context>] { ["a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F", "g", "G", "h", "H", "i", "I", "j", "J",
                               "k", "K", "l", "L", "m", "M", "n", "N", "o", "O", "p", "P", "q", "Q", "r", "R", "s", "S", "t", "T", "u", "U", "v", "V",
                               "w", "W", "x", "X", "y", "Y", "z", "Z"].map(LetterRecognizer.init) }
    
}

struct LetterRecognizer : Rule {
    
    var ruleName: String {
        "Letter \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws ->  some ASTNode {
        try Letter(char: char)
    }
    
}

// MARK: DIGIT

extension Rules {
    
    var digit : [any Rule<Context>] { (0...9).map(String.init).compactMap(\.first).map(DigitRecognizer.init) }
    
}

struct DigitRecognizer : Rule {
    
    var ruleName: String {
        "Digit \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws ->  some ASTNode {
        try Digit(char: char)
    }
    
}

// MARK: ONE-NINE

extension Rules {
    
    var oneNine : [any Rule<Context>] { (1...9).map(String.init).compactMap(\.first).map(OneNineRecognizer.init) }
    
}

struct OneNineRecognizer : Rule {
    
    var ruleName: String {
        "OneNine \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws -> some ASTNode {
        try OneNine(char: char)
    }
    
}

// MARK: List Nodes

struct Expression : ASTNode {
    let char : Character
}

struct CommaSeparatedexpressions : ASTNode {
    var exprs : [Expression]
}

// MARK: List Rules

struct RecNextIsList : Rule {
    
    @NonTerminal
    var recognized : CommaSeparatedexpressions
    
    @Terminal var separator = ","
    
    @NonTerminal
    var next : Expression
    
    func onRecognize(context: Context) throws -> some ASTNode {
        recognized.exprs.append(next)
        return recognized
    }
    
}

struct EmptyIsList : Rule {
    
    func onRecognize(context: Context) throws -> some ASTNode {
        CommaSeparatedexpressions(exprs: [])
    }
    
}

struct ExprIsList : Rule {
    
    @NonTerminal
    var expr : Expression
    
    func onRecognize(context: Context) throws -> some ASTNode {
        CommaSeparatedexpressions(exprs: [expr])
    }
    
}

struct CharIsExpr : Rule {
    
    var ruleName: String {
        "Char \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws -> some ASTNode {
        Expression(char: char)
    }
    
}

// MARK: List Grammar

struct ListGrammar : Grammar {
    var allRules: [any Rule<Context>] {
        ["a", "b", "c"].map(CharIsExpr.init) + [RecNextIsList(), EmptyIsList(), ExprIsList()]
    }
}
