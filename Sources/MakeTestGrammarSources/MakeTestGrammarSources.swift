import AST
import TestGrammars
import ArgumentParser
import Foundation

@main
struct Make : ParsableCommand {
    
    @Argument var file : String
    
    func run() throws {
        
        let url = URL(filePath: file)
        
        var gen = Sourcegen(module: "TestGrammars")
        
        try gen.makeSource(.CLR1(rules: Rules(), goal: IntOrIdentifier.self), as: "CLR1")
        
        try gen.buffer.write(to: url, atomically: true, encoding: .utf8)
        
    }
    
}
