//
//  APIType.swift
//  Krampus
//
//  Created by yangjx on 2022/4/24.
//  Copyright © 2022 nextop. All rights reserved.
//

import Foundation
import UIKit

public enum APIError: Error {
    case network
    case decode
    case timeout
    
    init(_ e: MError) {
        switch e {
        case .network:
            self = .network
        case .timeout:
            self = .timeout
        }
    }
}

public protocol APIType {
    associatedtype T: Decodable
    associatedtype Body
    associatedtype TypeError: Error
    var body: Body? { get }
//    func send(successHandle: @escaping(Result<T, TypeError>) -> Void)
    func asyncSend() async throws -> Result<T, TypeError>
}



// Web Socket
protocol WebAPIType: APIType where Body: Encodable {
    var sendId: String { get }
}

extension WebAPIType {
//    func send(successHandle: @escaping(Result<T, APIError>) -> Void) {
//        if MSession.default.isConnected {
//            MSession.default.sendMessage(messages: toMessage()) { response in
//                switch response.result {
//                case .success(let data):
//                    let decoder = JSONDecoder()
//                    if let responseData = try? decoder.decode(T.self, from: data) {
//                        successHandle(.success(responseData))
//                    } else {
//                        successHandle(.failure(.decode))
//                    }
//                case .failure(let error):
//                    successHandle(.failure(APIError(error)))
//                }
//            }
//        } else {
//            MSession.default.connect { r in
//                switch r {
//                case .success(_): send(successHandle: successHandle)
//                case .failure(_): successHandle(.failure(.network))
//                }
//            }
//        }
//    }
    
    public func asyncSend() async -> Result<T, APIError>  {
        do {
            let c = try await MSession.default.asyncConnect()
            guard c.isSuccess else {
                return .failure(.network)
            }
            let response = try await MSession.default.asyncSendMessage(messages: toMessage())
            switch response.result {
            case .success(let data):
                let decoder = JSONDecoder()
                if let responseData = try? decoder.decode(T.self, from: data) {
                    return .success(responseData)
                } else {
                    return .failure(.decode)
                }
            case .failure(let error):
                return .failure(APIError(error))
            }
        } catch  {
            return .failure(.network)
        }
    }
    
    func toMessage() ->  MMessage {
        guard let data = try? JSONEncoder().encode(body) else {
            fatalError()
        }
        return MMessage(data, requestId: sendId)
    }
}


