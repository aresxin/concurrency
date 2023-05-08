

import Foundation
 
@globalActor actor SerialActor: GlobalActor {
    typealias ActorType = SerialActor
    static let shared: SerialActor = SerialActor()
    private static let _sharedExecutor = SyncExectuor()
    static let sharedUnownedExecutor: UnownedSerialExecutor = _sharedExecutor.asUnownedSerialExecutor()
    let unownedExecutor: UnownedSerialExecutor = sharedUnownedExecutor
}


final class SyncExectuor: SerialExecutor {
    private static let dispatcher: DispatchQueue = DispatchQueue(label: "momiji.session.actior")
    
    func enqueue(_ job: UnownedJob) {
        print("enqueue")
        SyncExectuor.dispatcher.async {
            job._runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
    
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}
