import XCTest
import AST

final class ASTTests: XCTestCase {
    
    func testIdOrInt() throws {
        
        let parser = try Parser.CLR1(rules: Rules(), goal: IntOrIdentifier.self)
        
        let num = 134890024502403
        try XCTAssertEqual(parser.parse("\(num)"), .integer(num))
        
        XCTAssertThrowsError(try parser.parse("1203240a"))
        
        let str = "a2450236taAFwegaeF005389"
        try XCTAssertEqual(parser.parse(str), .identifier(Identifier(string: str)))
        
    }
    
    func testInt() throws {
        
        let parser = try Parser.CLR1(rules: Rules(), goal: Int.self)
        
        for num in [124050, 130480, 300950480, 1023840209, 38239840831049804, 190480948] {
            
            try XCTAssertEqual(parser.parse("\(num)"), num)
            
        }
        
    }
    
    func testIdentifier() throws {
        
        let parser = try Parser.CLR1(rules: Rules(), goal: Identifier.self)
        
        for str in ["a1253ga325346", "efaghlkhgklnalrk", "AFEALFKHafhs", "ohIAEFho2345sfdh"] {
            try XCTAssertEqual(parser.parse(str), Identifier(string: str))
        }
        
        for str in ["12hai", "2aeugho", "3LHafNA3"] {
            XCTAssertThrowsError(try parser.parse(str))
        }
        
    }
    
    func testDigit() throws {
        
        let parser = try Parser.CLR1(rules: Rules(), goal: Digit.self)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(parser.tables)
        
        print(String(data: data, encoding: .utf8)!)
        
        let newParser = try JSONDecoder().decode(ParserTables<Rules>.self, from: data)
        
        XCTAssertEqual(parser.tables, newParser)
        
    }
    
    func testList() throws {
        
        let parser = try Parser.CLR1(rules: ListGrammar(), goal: CommaSeparatedexpressions.self)
        
        try XCTAssertEqual(parser.parse("a,b,a")?.exprs.map(\.char), ["a", "b", "a"])
        
    }
    
    func testOptional() throws {
        let parser = try Parser.CLR1(rules: OptionGrammar(), goal: Success.self)
        try XCTAssertNotNil(parser.parse(""))
        try XCTAssertNotNil(parser.parse("A"))
    }
    
    func testPerformance() throws {
        
        let parser = try Parser.CLR1(rules: Rules(), goal: IntOrIdentifier.self)
        
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

// MARK: UTILS TESTS

struct OptionGrammar : Grammar {
    let constructors : [any Constructors<Context>] = [SuccessRules(), Maybe<Letter, Context>(), ARules()]
    
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

struct Success : ASTNode {}

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

struct Rules : Grammar {
    
    typealias Ctx = AST.Context
    
    var constructors : [any Constructors<Ctx>] {idOrInt + identifierRecursion + numberRecursion + lowerLevel}
    
    var lowerLevel : [any Constructors<Ctx>] { digitsOrLetters + letter + digit + oneNine }
    
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
    init(_ oneNine: OneNine, _ digits: [Digit]) throws {
        guard let int = Int(String(oneNine.char) + digits.map(\.char)) else {
            throw NSError()
        }
        self = int
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
    
    var idOrInt : [any Constructors<Ctx>] { [ConstructorList(IdentifierIDOrInt(), IntIDOrInt())] }
    
}

struct IntIDOrInt : Constructor {
    
    @NonTerminal
    var int : Int
    
    func onRecognize(context: Context) throws -> IntOrIdentifier {
        IntOrIdentifier.integer(int)
    }
    
}

struct IdentifierIDOrInt : Constructor {
    
    @NonTerminal
    var id : Identifier
    
    func onRecognize(context: Context) throws -> IntOrIdentifier {
        IntOrIdentifier.identifier(id)
    }
    
}

// MARK: IDENTIFIER

extension Rules {
    
    var identifierRecursion : [any Constructors<Ctx>] { [ConstructorList(LetterIdentifier(), LetterDigitsOrLettersIsIdentifier())] }
    
}

struct LetterDigitsOrLettersIsIdentifier : Constructor {
    
    @NonTerminal
    var letter : Letter
    
    @NonTerminal
    var digitsOrLetters : DigitsOrLetters
    
    func onRecognize(context: Context) throws -> Identifier {
        return Identifier(string: String(letter.char) + digitsOrLetters.string) // slow...
    }
    
}

struct LetterIdentifier : Constructor {
    
    @NonTerminal
    var letter : Letter
    
    func onRecognize(context: Context) throws -> Identifier {
        Identifier(string: String(letter.char))
    }
    
}

// MARK: DIGITS OR LETTERS

extension Rules {
    
    var digitsOrLetters : [any Constructors<Ctx>] { [ConstructorList(DigitsOrLettersRecursion(), DigitOrLetterIsDigitsOrLetters()), ConstructorList(LetterIsDigitOrLetter(),DigitIsDigitOrLetter())] }
    
}

struct DigitsOrLettersRecursion : Constructor {
    
    @NonTerminal
    var known : DigitsOrLetters
    
    @NonTerminal
    var new : DigitOrLetter
    
    func onRecognize(context: Context) throws -> DigitsOrLetters {
        known.string.append(new.char)
        return known
    }
    
}

struct DigitOrLetterIsDigitsOrLetters : Constructor {
    
    @NonTerminal
    var digitOrLetter : DigitOrLetter
    
    func onRecognize(context: Context) throws -> DigitsOrLetters {
        DigitsOrLetters(string: String(digitOrLetter.char))
    }
    
}

struct LetterIsDigitOrLetter : Constructor {
    
    @NonTerminal var letter : Letter
    
    func onRecognize(context: Context) throws -> DigitOrLetter {
        DigitOrLetter(char: letter.char)
    }
    
}

struct DigitIsDigitOrLetter : Constructor {
    
    @NonTerminal var digit : Digit
    
    func onRecognize(context: Context) throws -> DigitOrLetter {
        DigitOrLetter(char: digit.char)
    }
    
}

// MARK: NUMBER

extension Rules {
    
    var numberRecursion : [any Constructors<Ctx>] { [NonEmptyListRecognizer<Digit, Ctx>(), ConstructorList(NumberRecognizer())] }
    
}

struct NumberRecognizer : Constructor {
    
    @NonTerminal var oneNine : OneNine
    @NonTerminal var digits : [Digit]
    
    func onRecognize(context: Context) throws ->  Int {
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

struct LetterRecognizer : Constructor {
    
    var ruleName: String {
        "Letter \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws -> Letter {
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

struct DigitRecognizer : Constructor {
    
    var ruleName: String {
        "Digit \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws -> Digit {
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

struct OneNineRecognizer : Constructor {
    
    var ruleName: String {
        "OneNine \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws -> OneNine {
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

struct RecNextIsList : Constructor {
    
    @NonTerminal
    var recognized : CommaSeparatedexpressions
    
    @Terminal var separator = ","
    
    @NonTerminal
    var next : Expression
    
    func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        recognized.exprs.append(next)
        return recognized
    }
    
}

struct EmptyIsList : Constructor {
    
    func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        CommaSeparatedexpressions(exprs: [])
    }
    
}

struct ExprIsList : Constructor {
    
    @NonTerminal
    var expr : Expression
    
    func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        CommaSeparatedexpressions(exprs: [expr])
    }
    
}

struct CharIsExpr : Constructor {
    
    var ruleName: String {
        "Char \(char)"
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws -> Expression {
        Expression(char: char)
    }
    
}

// MARK: List Grammar

struct ListGrammar : Grammar {
    var constructors: [any Constructors<Context>] {
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
