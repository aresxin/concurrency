# concurrency
concurrency research


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
总结一下，Task在actor内会继承这个actor环境，Task里面的异步任务挂起和回复都在这个actor线程内，也可以访问这个actor的isolated属性
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
