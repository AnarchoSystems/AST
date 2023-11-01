//
//  ClosedGraph.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public protocol Node : Hashable {
    associatedtype Edge : Hashable
    associatedtype Lookup
    func canReach(lookup: inout Lookup) throws -> [Edge: [Self]]
}

public struct ClosedGraph<N : Node> : Hashable {
    
    public let nodes : [N]
    public let edges : [N.Edge : [Int : [Int]]]
    
    public init(seeds: [N], lookup: inout N.Lookup) throws {
        
        // local variables so they're mutable
        var nodes = seeds
        var edges : [N.Edge : [N : Set<N>]] = [:]
        
        // we need these to keep track of nodes to expand
        var newNodes = seeds
        var seenNodes : Set<N> = Set(seeds)
        
        while true {
            
            let upcomingNodes = newNodes
            newNodes = []
            
            for start in upcomingNodes {
                for (content, ends) in try start.canReach(lookup: &lookup) {
                    for end in ends {
                        
                        if !seenNodes.contains(end) {
                            seenNodes.insert(end)
                            newNodes.append(end)
                        }
                        if edges[content] == nil {
                            edges[content] = [start : [end]]
                        }
                        else if edges[content]![start] == nil {
                            edges[content]![start] = [end]
                        }
                        else {
                            edges[content]![start]!.insert(end)
                        }
                    }
                }
            }
            
            if newNodes.isEmpty {
                break
            }
            nodes.append(contentsOf: newNodes)
        }
        
        self.nodes = nodes
        
        // every edge must now begin and end at a node in the nodes array
        self.edges = edges.mapValues{dict in
            Dictionary(uniqueKeysWithValues: dict.map{key, vals in (nodes.firstIndex(of: key)!,
                                                                    vals.map{nodes.firstIndex(of: $0)!})})
        }
    }
    
}
