import PackagePlugin

@main
struct MyPlugin: BuildToolPlugin {
    
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        try [.buildCommand(displayName: "Generate Test Grammar Sources",
                           executable: context.tool(named: "MakeTestGrammarSources").path,
                           arguments: [context.pluginWorkDirectory.appending(subpath: "Parsers.swift")],
                           inputFiles: target.dependencies.compactMap{dep in
            guard case .target(let targ) = dep, targ.name == "TestGrammars" else {
                return nil
            }
            return targ.directory.appending(subpath: "MakeTestGrammarSources.swift")
        },
                           outputFiles: [context.pluginWorkDirectory.appending(subpath: "Parsers.swift")])]
    }
}
