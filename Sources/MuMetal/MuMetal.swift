//
//  File.swift
//  
//
//  Created by warren on 3/25/23.
//

import Foundation
import Metal

public class MuMetal {
    
    public static let bundle = Bundle.module

    public static func read(_ filename: String,
                            _ ext: String) -> String? {

        guard let path = Bundle.module.path(forResource: filename, ofType: ext)  else {
            print("🚫 MuMeta::read couldn't find file: \(filename).\(ext)")
            return nil
        }
        do {
            return try String(contentsOfFile: path) }
        catch {
            print("🚫 MuMetal::read error:\(error) loading contents of:\(path)")
        }
        return nil
    }
    

}
