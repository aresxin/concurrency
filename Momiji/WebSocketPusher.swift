

import Foundation
import Combine
enum WebSocketError: Error {
    
}
class WebSocketPusher: NSObject, MSessionDelegate {
    func didReceivePushMessage(_ message: String) {
        guard let m = CastWebSocketMessage(jsonString: message) else {
            return
        }
        guard let payload = try? m.decodePayload()  else { return }
        handldPayload(payload)
    }
    
    // Combine Publisher
//    let quoteSubject = PassthroughSubject<QuoteV1Event, Error>()
    let chartSubject = PassthroughSubject<ChartV1Event, Error>()
    
    
    let quoteSubject = PassthroughSubject<[QuoteV1], Error>()

    @objc static let sharedInstance = WebSocketPusher()
    private override init() {
        super.init()
    }
    
//    @objc
//    func websocketDidReceiveMessage(text: String) {
//        dump("--------------\(text)")
//        guard let m = CastWebSocketMessage(jsonString: text) else {
//            return
//        }
//        handldWebSocketMessage(m)
//    }
    
//    func handldWebSocketMessage(_ m: CastWebSocketMessage) {
//        switch m.type {
//        case .QUOTE:
//            guard let payload = try? m.decodePayload() else { return }
//            handldPayload(payload)
//        case .CHART:
//            guard let payload = try? m.decodePayload() else { return }
//            handldPayload(payload)
//        }
//    }
    
    func handldPayload(_ p: MessagePayload) {
        switch p {
        case ._quote(let quoteV1Event):
            dump("quoteV1Event payload is --------\(quoteV1Event)")
            quoteSubject.send(quoteV1Event.quotes)
        case ._chart(let chartV1):
            dump("chartV1 payload is --------\(chartV1)")
            chartSubject.send(chartV1)
        case ._market(let marketV1):
            dump("_market payload is --------\(marketV1)")
        }
    }
}
