//
//  WebSocketMessage.swift
//  Krampus
//
//  Created by yangjx on 2022/4/19.
//  Copyright © 2022 nextop. All rights reserved.
//

import Foundation
let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
}()


enum MessagePayload {
    case _quote(QuoteV1Event)
    case _chart(ChartV1Event)
    case _market(MarketV1Event)
    
    init(type: MessageType, data: Data) throws {
        switch type {
        case .QUOTE:
            let message = try decoder.decode(QuoteV1Event.self, from: data)
            self = ._quote(message)
        case .CHART:
            let message = try decoder.decode(ChartV1Event.self, from: data)
            self = ._chart(message)
        case .MARKET:
            let message = try decoder.decode(MarketV1Event.self, from: data)
            self = ._market(message)
        }
    }
}


enum MessageType: String {
    case QUOTE
    case CHART
    case MARKET
}
struct CastWebSocketMessage {
    static let typeKey = "event"
    static let dataKey = "data"
    let type: MessageType
    let data: Data
    
    init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
           return nil
        }
        let object = try? JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
          return nil
        }
        
        guard let t = dictionary[CastWebSocketMessage.typeKey] as? String, let type = MessageType(rawValue: t) else {
            return nil
        }
        
        guard let obj = dictionary[CastWebSocketMessage.dataKey], let data = try? JSONSerialization.data(withJSONObject: obj)  else {
            return nil
        }
        self.type = type
        self.data = data
        //dump(dictionary)
    }
    
    func decodePayload() throws -> MessagePayload {
        return try .init(type: type, data: data)
    }
}
