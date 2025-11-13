//
//  Object+Extension.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 04/11/2025.
//

import Foundation
import RealmSwift

extension Object {
    func shallowJSONString() -> String? {
        var dict = [String: Any]()
        for property in objectSchema.properties {
            let value = self.value(forKey: property.name)
            if value is String || value is Int || value is Double || value is Bool {
                dict[property.name] = value
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
