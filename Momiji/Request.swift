//
//  Request.swift
//  Krampus
//
//  Created by yangjx on 2022/4/25.
//  Copyright © 2022 nextop. All rights reserved.
//

import Foundation


struct MarketRequest: WebAPIType {
    typealias Body = SubscribeMarketV1EventRequest
    
    typealias T = SubscribeMarketV1EventResponse
    
    let sendId =  "\(IdGenerator.nextId())"
    
    var body: Body? {
        return SubscribeMarketV1EventRequest(request_id: sendId)
    }
}


struct SubscribeQuoteRequest: WebAPIType {
    typealias Body = SubscribeQuoteV1EventRequest
    typealias T = SubscribeQuoteV1EventResponse
    
    let sendId =  "\(IdGenerator.nextId())"
    
    let contractIds: [Int32]
    
    init(_ contractIds: [Int32]) {
        self.contractIds = contractIds
    }
    
    var body: Body? {
        return SubscribeQuoteV1EventRequest(request_id: sendId, contractIds: contractIds)
    }
}
