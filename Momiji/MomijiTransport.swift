//
//  MomijiTransport.swift
//  Krampus
//
//  Created by yangjx on 2022/4/22.
//  Copyright © 2022 nextop. All rights reserved.
//

import Foundation
import Starscream


public enum MSocketEvent {
    case connected([String: String])
    case disconnected(String, UInt16)
    case text(String)
    case binary(Data)
    case pong(Data?)
    case ping(Data?)
    case error(Error?)
    case viabilityChanged(Bool)
    case reconnectSuggested(Bool)
    case cancelled
}



public protocol MTransportDelegate: AnyObject {
    func didReceive(_ event: MSocketEvent)
}


class MTransport {
    let socket: WebSocket
    private(set) var isConnected: Bool = false
    weak var delegate: MTransportDelegate? = nil
    private var pingTimer: Timer?
    public init(_ request: URLRequest){
        socket = WebSocket(request: request, useCustomEngine: false)
        socket.onEvent = { [weak self] event in
            guard let `self` = self else { return }
            switch event {
            case .connected(let headers):
                self.isConnected = true
                self.pingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                    guard let `self` = self else { return }
                    if self.isConnected {
                        self.socket.write(ping: Data()) {
                            
                        }
                    }
                }
                self.delegate?.didReceive(.connected(headers))
            case .disconnected(let reason, let code):
                self.isConnected = false
                self.delegate?.didReceive(.disconnected(reason, code))
                //print("-----------websocket is disconnected: \(reason) with code: \(code)")
            case .text(let string):
                //print("----------Received text: \(string)")
                self.delegate?.didReceive(.text(string))
            case .binary(let data):
                //print("---------Received data: \(data.count)")
                self.delegate?.didReceive(.binary(data))
            case .ping(_):
                break
            case .pong(_):
                break
            case .viabilityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            case .cancelled:
                self.isConnected = false
            case .error(let error):
                self.isConnected = false
                self.delegate?.didReceive(.error(error))
            }
        }
    }
    
    func connect() {
       socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func sendData(_ data: Data) {
        guard let string = String.init(data: data , encoding: .utf8) else { return  }
        socket.write(string: string)
        
//        print("json to load: \(string)")
//        //socket.write(data: data)
//
//        do {
//            // make sure this JSON is in the format we expect
//            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//                // try to read out a string array
//                print("json to load: \(json)")
//            }
//        } catch let error as NSError {
//            print("Failed to load: \(error.localizedDescription)")
//        }
    }
    
}
