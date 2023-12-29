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

// List -> ''

struct EmptyIsList : Constructor {
    
    func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        CommaSeparatedexpressions(exprs: [])
    }
    
}

// List -> <Expr>
// we need this rule because we used left recursion and allow empty lists
// without this rule our lists would have to look like ",a,b,a"


struct ExprIsList : Constructor {
    
    @NonTerminal
    var expr : Expression
    
    func onRecognize(context: Context) throws -> CommaSeparatedexpressions {
        CommaSeparatedexpressions(exprs: [expr])
    }
    
}

// Expr -> <any characters in our alphabet>


struct CharIsExpr : Constructor {
    
    var ruleName: String {
        "Char \(char)" // we need to distinguish the rules for each character
    }
    
    @Terminal var char : Character
    
    func onRecognize(context: Context) throws -> Expression {
        Expression(char: char)
    }
    
}


```

We can now summarize the Rules into a Grammar:

```Swift
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

```

And finally, let's run a test!

```Swift

    func testList() throws {
                
        let parser = try Parser.CLR1(rules: ListGrammar(), goal: CommaSeparatedexpressions.self)
        
        try XCTAssertEqual(parser.parse("a,b,a").get().exprs.map(\.char), ["a", "b", "a"]) // works!
        
        
    }
    
```
