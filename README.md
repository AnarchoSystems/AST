# AST

With this library, the Abstract Syntax Tree of a grammar becomes a custom object that you can traverse in whatever way you like.

## Declaring Rules

Suppose, these are our AST node types

```Swift
struct Expression : ASTNode {
    let char : Character
}

struct CommaSeparatedexpressions : ASTNode {
    var exprs : [Expression]
}
```

Our goal is to recognize a comma separated list of expressions, and for the sake of a simple example, expressions are just characters.

Let us declare the necessary rules for that:

```Swift

// List -> <List> ',' <Expr>

struct RecNextIsList : Rule {
    
    @NonTerminal
    var recognized : CommaSeparatedexpressions
    
    @Terminal var separator = ","
    
    @NonTerminal
    var next : Expression
    
    func onRecognize(in range: ClosedRange<String.Index>, context: Context) throws -> some ASTNode {
        recognized.exprs.append(next) // we used left recursion so this is basically O(1)
                                      // note that we own the memory of "recognized"!
        return recognized
    }
    
}

// List -> ''

struct EmptyIsList : Rule {
    
    func onRecognize(in range: ClosedRange<String.Index>, context: Context) throws -> some ASTNode {
        CommaSeparatedexpressions(exprs: [])
    }
    
}

// List -> <Expr>
// we need this rule because we used left recursion and allow empty lists
// without this rule our lists would have to look like ",a,b,a"

struct ExprIsList : Rule {
    
    @NonTerminal
    var expr : Expression
    
    func onRecognize(in range: ClosedRange<String.Index>, context: Context) throws -> some ASTNode {
        CommaSeparatedexpressions(exprs: [expr])
    }
    
}

// Expr -> <any characters in our alphabet>

struct CharIsExpr : Rule {
    
    var ruleName: String {
        "Char \(char)" // we need to distinguish the rules for each character
    }
    
    @Terminal var char : Character
    
    func onRecognize(in range: ClosedRange<String.Index>, context: Context) throws -> some ASTNode {
        Expression(char: char)
    }
    
}

```

We can now summarize the Rules into a Grammar:

```Swift
struct ListGrammar : Grammar {
    var allRules: [any Rule] {
        ["a", "b", "c"].map(CharIsExpr.init) + [RecNextIsList(), EmptyIsList(), ExprIsList()]
    }
}
```

And finally, let's run a test!

```Swift

    func testList() throws {
        
        let parser = try Parser.CLR1(rules: ListGrammar.self, goal: CommaSeparatedexpressions.self)
        
        try XCTAssertEqual(parser.parse("a,b,a")?.exprs.map(\.char), ["a", "b", "a"]) //works!
        
    }
    
```
