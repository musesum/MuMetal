//  created by musesum on 12/29/19.

import Foundation

extension MetalNode {

    @discardableResult
    public func insert(before: MetalNode?) -> MetalNode? {
        if let before {
            if before.id == self.id { return self }
            inNode = before.inNode
            outNode = before
            before.inNode = self
        }
        return self
    }
    
    @discardableResult
    public func insert(after: MetalNode?) -> MetalNode {
        if let after {
            if after.id == self.id { return self }
            inNode = after
            // avoid creating a loop if already inserted before
            if after.outNode != self {
                outNode = after.outNode
                after.outNode = self
            }
        }
        return self
    }

    public enum InsertWhere { case above, below }

    @discardableResult
    public func insertNode(_ insertNode: MetalNode,
                           _ insertWhere: InsertWhere) -> MetalNode? {

        if insertNode.id == self.id { return self }

        switch insertWhere {

            case .above:
                // already inserted above?
                if insertNode.outNode == self,
                   self.inNode == insertNode { return self }

                insertNode.inNode = inNode
                insertNode.outNode = self
                insertNode.inTex = inTex
                insertNode.outTex = makeNewTex("insertNode.above")

                inNode?.outNode = insertNode
                inNode = insertNode
                inTex = insertNode.outTex

            case .below:
                // already inserted below
                if insertNode.inNode == self,
                   self.outNode == insertNode { return self }

                insertNode.inNode = self
                insertNode.outNode = outNode
                insertNode.inTex = outTex
                insertNode.outTex = makeNewTex("insertNode.below")

                outNode?.inNode = insertNode
                outNode?.inTex = insertNode.outTex
                outNode = insertNode
        }
        return self
    }
    @discardableResult
    public func replace(with newNode: MetalNode) -> MetalNode? {

        // ignore replaceing self with self
        if newNode.id == self.id { return self }

        // ignore false positive, where self is not in pipeline
        if inNode == nil, outNode == nil { return newNode }

        newNode.inTex = inTex
        newNode.outTex = outTex
        newNode.altTex = altTex
        newNode.outNode = outNode
        newNode.inNode = inNode
        newNode.pipeline.drawSize = pipeline.drawSize

        if  inNode?.outNode?.id == id {
            inNode?.outNode = newNode
        }
        if  outNode?.inNode?.id == id {
            outNode?.inNode = newNode
        }
        return newNode
    }


}
