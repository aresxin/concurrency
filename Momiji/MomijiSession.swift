//
//  MomijiSession.swift
//  Krampus
//
//  Created by yangjx on 2022/4/22.
//  Copyright © 2022 nextop. All rights reserved.
//

import Foundation
public enum MError: Error {
    case network
    case timeout
}

extension Result {
    /// Returns whether the instance is `.success`.
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }

    /// Returns whether the instance is `.failure`.
    var isFailure: Bool {
        !isSuccess
    }

    /// Returns the associated value if the result is a success, `nil` otherwise.
    var success: Success? {
        guard case let .success(value) = self else { return nil }
        return value
    }

    /// Returns the associated error value if the result is a failure, `nil` otherwise.
    var failure: Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

public struct MDataResult<Success, Failure: Error> {
    public let data: Data?
    public let result: Result<Success, Failure>
    public var value: Success? { result.success }
    public var error: Failure? { result.failure }
    public let metrics: TimeInterval
    
    init(_ result: Result<Success, Failure>, _ data: Data? = nil, _ metrics: TimeInterval = 0) {
        self.result = result
        self.data = data
        self.metrics = metrics
    }
}


public typealias CallCallback = (MDataResult<Data, MError>) -> Void
public typealias ConnectedCallback = (Swift.Result<[String : String]?, MError>) -> Void
public typealias DisconnectedCallback = (String, UInt16) -> Void

open class MMessage {
    let requestId: String
    let body: Data
    let timeout: TimeInterval = 5.0
    init(_ body: Data, requestId: String) {
        self.body = body
        self.requestId = requestId
    }
}

public protocol MSessionDelegate: AnyObject {
    func didReceivePushMessage(_ message: String)
}

@SerialActor
open class MSession {
    
//    private let dispatcher: DispatchQueue = DispatchQueue(label: "momiji.session.actior")
    
    public weak var delegate: MSessionDelegate?
    nonisolated public var isConnected: Bool {
        return transport.isConnected
    }
    public private(set) var isConnecting: Bool = false
    
    fileprivate var callRequests: [String: (CallCallback, TimeInterval)] = [:]
    fileprivate var connectedCallBackList: [ConnectedCallback] = []
    
    private let transport: MTransport
    
    required public init(_ request: URLRequest) {
        transport = MTransport(request)
        transport.delegate = self
    }

    
    public func connect(completionHandler: @escaping ConnectedCallback) {
//        dispatcher.async { [weak self] in
//            guard let `self` = self else { return }
//            self._connect(completionHandler: completionHandler)
//        }
        guard !isConnected else {
            completionHandler(.success(nil))
            return
        }
        guard !isConnecting else {
            connectedCallBackList.append(completionHandler)
            return
        }

        connectedCallBackList.append(completionHandler)

        transport.connect()
        isConnecting = true
    }
    
    private func _connect(completionHandler: @escaping ConnectedCallback) {
        guard !isConnected else {
            completionHandler(.success(nil))
            return
        }
        guard !isConnecting else {
            connectedCallBackList.append(completionHandler)
            return
        }
        
        connectedCallBackList.append(completionHandler)
        
        transport.connect()
        isConnecting = true
    }
    
    public func asyncConnect() async throws -> Swift.Result<[String : String]?, MError>  {
        return try await withCheckedThrowingContinuation { continuation in
            connect { result in
                continuation.resume(with: .success(result))
            }
        }
    }

    public func disconnect() {
        transport.disconnect()
    }
    
    
    public func sendMessage(messages: MMessage,  completionHandler: @escaping CallCallback) {
        callRequests[messages.requestId] = (completionHandler, Date().timeIntervalSinceNow)
        transport.sendData(messages.body)
        
        // Timeout
        delay(messages.timeout) { [weak self] in
            if let (callback, _)  = self?.callRequests.removeValue(forKey: messages.requestId) {
                let r = MDataResult<Data, MError>(.failure(.timeout))
                callback(r)
            }
        }
    }
    
    
    public func asyncSendMessage(messages: MMessage) async throws -> MDataResult<Data, MError>  {
        return try await withCheckedThrowingContinuation { continuation in
            self.sendMessage(messages: messages) { result in
                continuation.resume(with: .success(result))
            }
        }
    }
}


extension MSession: MTransportDelegate {
    
    public func didReceive(_ event: MSocketEvent) {
        switch event {
        case .connected(let headers):
            for call in connectedCallBackList {
                call(.success(headers))
            }
            connectedCallBackList = []
        case .cancelled:
            for call in connectedCallBackList {
                call(.failure(.timeout))
            }
            connectedCallBackList = []
        case .disconnected(let reason, let code):
            dump("disconnected headers is \(reason) \(code)")
        case .text(let string):
//            print("Received text: \(string)")
            if let data = string.data(using: .utf8) {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: AnyObject]
                    guard let id = json?["id"] as? String else {
                        delegate?.didReceivePushMessage(string)
                        return
                    }
                    if let (callback, start)  = callRequests.removeValue(forKey: id) {
                        let t = Date().timeIntervalSinceNow - start
                        let r = MDataResult<Data, MError>(.success(data), data, t)
                        callback(r)
                    } else {
                        delegate?.didReceivePushMessage(string)
                    }
                } catch {
                    print("Something went wrong")
                }
            }
        case .error(let error):
//            print("error text: \(error)")
            for key in callRequests.keys {
                if let (callback, _)  = callRequests.removeValue(forKey: key) {
                    let r = MDataResult<Data, MError>(.failure(.timeout))
                    callback(r)
                }
            }
        default:
            break
        }
    }
}
