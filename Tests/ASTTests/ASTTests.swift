import XCTest
import AST
import TestGrammars

final class ASTTests: XCTestCase {
    
    func testIdOrInt() throws {
        
        let parser = Rules.CLR1(Rules())
        
        let num = 134890024502403
        try XCTAssertEqual(parser.parse("\(num)").get(), .integer(num))
        
        XCTAssertThrowsError(try parser.parse("1203240a").get())
        
        let str = "a2450236taAFwegaeF005389"
        try XCTAssertEqual(parser.parse(str).get(), .identifier(Identifier(string: str)))
        
    }
    
    func testInt() throws {
        
        let parser = try Parser.CLR1(rules: Rules(), goal: Int.self)
        
        for num in [124050, 130480, 300950480, 1023840209, 38239840831049804, 190480948] {
            
            try XCTAssertEqual(parser.parse("\(num)").get(), num)
            
        }
        
    }
    
    func testIdentifier() throws {
        
        let parser = try Parser.CLR1(rules: Rules(), goal: Identifier.self)
        
        for str in ["a1253ga325346", "efaghlkhgklnalrk", "AFEALFKHafhs", "ohIAEFho2345sfdh"] {
            try XCTAssertEqual(parser.parse(str).get(), Identifier(string: str))
        }
        
        for str in ["12hai", "2aeugho", "3LHafNA3"] {
            XCTAssertThrowsError(try parser.parse(str).get())
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
        
        try XCTAssertEqual(parser.parse("a,b,a").get().exprs.map(\.char), ["a", "b", "a"])
        
    }
    
    func testOptional() throws {
        let parser = try Parser.CLR1(rules: OptionGrammar(), goal: Success.self)
        try XCTAssertNotNil(parser.parse("").get())
        try XCTAssertNotNil(parser.parse("A").get())
    }
    
    func testPerformance() throws {
        
        let parser = Rules.CLR1(Rules())
        
        measure {
            do {
                let num = 134890024502403
                _ = try parser.parse("\(num)").get()
            }
            catch {
                XCTFail()
            }
        }
        
    }
    
}
