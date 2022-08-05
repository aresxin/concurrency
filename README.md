# concurrency
concurrency research


## async/await
[Swift 新并发框架之 async/await](https://juejin.cn/post/7076733264798416926) <br>
[将回调改写成 async 函数](https://www.bennyhuo.com/book/swift-coroutines/02-wrap-callback.html) <br>
``` ruby
提供2组函数一个抛出异常，一个不抛出异常
public func withCheckedContinuation<T>(
    function: String = #function, 
    _ body: (CheckedContinuation<T, Never>) -> Void
) async -> T

public func withCheckedThrowingContinuation<T>(
    function: String = #function, 
    _ body: (CheckedContinuation<T, Error>) -> Void
) async throws -> T
```

[理解]
``` ruby
await 暂停的是方法，而不是执行方法的线程；
await 暂停点前后可能会发生线程切换。
await 之所以称为『 潜在 』暂停点，而不是暂停点，是因为并不是所有的 await 都会暂停，只有遇到类似 IO、手动起子线程等情况时才会暂停当前调用栈的运行。
如果 await后没有异步操作，会立刻返回结果。
```
[代码解析]
``` ruby
asyncConnect把connect方法改写成异步函数， transport.connect()调用之后开始真正的暂停，因为transport.connect()是子线程异步操作

let c = try await MSession.default.asyncConnect()

 public func connect(completionHandler: @escaping ConnectedCallback) {
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
```


## Task
[Swift 新并发框架之 Task](https://juejin.cn/post/7084640887250092062/) <br>
[在程序当中调用异步函数 Task](https://www.bennyhuo.com/book/swift-coroutines/03-call-async-func.html#%E4%BD%BF%E7%94%A8-task) <br>

[理解]
``` ruby
Task 是线程的高级抽象，可以理解为创建一个线程Task，在这个线程上执行异步任务，就是Task的闭包里执行的任务在这个线程上。
如果是在 actor 方法中调用 Task.init 的，则 Task closure 将成为 actor-isolated。Task继承这个actor环境， Task里面异步任务挂起和暂停的地方都在这个actor 线程上
```
[代码解析]
``` ruby
因为这类是@MainActor，所以Task的环境继承mainactor，异步任务挂起和恢复都在主线程，异步任务恢复之后可以访问mainactor的isolated属性
总结一下，Task在actor内会继承这个actor环境，Task里面的异步任务挂起和恢复都在这个actor线程内，也可以访问这个actor的isolated属性
@MainActor
class RateDataSource: ObservableObject {
    weak var delegate : RateModelDelegate? = nil
    var storage = Set<AnyCancellable>()
    @Published var rates: [QuoteV1] = []
    func loadData() {
        WebSocketPusher.sharedInstance.quoteSubject.sink { error in
            
        } receiveValue: { [weak self] quotes in
            dump("push quotes is \(quotes)")
            self?.onQuotesService(quotes: quotes, first: false)
        }.store(in: &self.storage)
        
        Task {
            // 异步任务挂起的地方在主线程，因为这个类是mainactor
            guard let contracts = await MarketRequest().asyncSend().success?.data?.contracts else {
                return
            }
            // 异步任务恢复的地方在主线程，因为这个类是mainactor
            let ids = contracts.map({ c in return c.id_p })
            let quote = await SubscribeQuoteRequest(ids).asyncSend().success?.data?.quotes
            onQuotesService(quotes: quote)
            dump("Subscribe quotes is \(String(describing: quote))")
        }
    }
    
    
    func onQuotesService(quotes: [QuoteV1]?, first: Bool = true) {
        guard let q = quotes else {
            return
        }
        if first {
            self.rates = q
            print("first rates count is \(rates.count)")
        } else {
            self.rates.mergeWithOrdering(mergeWith: q, uniquelyKeyedBy: \.contractId)
            print("merge 0--- rates count is \(rates.count)")
        }
      
    }
    
    func unload() {
        storage.removeAll()
    }
}

``` 
## actor
[Swift 新并发框架之 actor](https://juejin.cn/post/7076738494869012494) <br>
[GlobalActor 和异步函数的调度](https://www.bennyhuo.com/book/swift-coroutines/07-globalactor.html) <br>

[理解]
``` ruby
Actor 代表一组在并发环境下可以安全访问的(可变)状态；
Actor 通过所谓数据隔离 (Actor isolation) 的方式确保数据安全，其实现原理是 Actor 内部维护了一个串行队列 (mailbox)，所有涉及数据安全的外部调用都要入队，即它们都是串行执行的。
```

[代码解析]
``` ruby
自己实现一个actor这个actor的job都在穿行队列dispatcher执行。
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
```
## Sendable
[Swift 新并发框架之 Sendable](https://juejin.cn/post/7076741945820872717/) <br>

[理解]
``` ruby
Sendable closure 是不能捕获 actor-isolated 属性，否则报错: Actor-isolated property 'x' can not be referenced from a Sendable closure。
但 Task closure 是个例外，因为它本身也是 actor-isolated，所以下面的代码不会报错：
public actor TestActor {
  var value: Int = 0

  func testTask() {
    Task {
      value = 1
    }
 }
}
```
## TaskLocal
[TaskLocal](https://www.bennyhuo.com/book/swift-coroutines/08-tasklocal.html) <br>


## Instrument 14 swift concurrency 模板
[WWDC22 110350 Swift 并发的可视化和优化](https://xiaozhuanlan.com/topic/0186237549) <br>
