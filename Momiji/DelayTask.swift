//
//  DelayTask.swift
//  Krampus
//
//  Created by yangjx on 2022/4/25.
//  Copyright © 2022 nextop. All rights reserved.
//

import Foundation

public func delay(_ interval: TimeInterval, block: @escaping ()->()) {
    let delayTime = DispatchTime.now() + interval
    DispatchQueue.main.asyncAfter(deadline: delayTime) {
        block()
    }
}



public typealias DelayTask = (_ cancel: Bool) -> Void

public func dispatch_later(_ interval: TimeInterval, block: @escaping ()->()) -> DelayTask? {

    var closure: (() -> Void)? = block
    var result: DelayTask?
    let delayClosure: DelayTask = { cancel in
        if let theClosure = closure {
            if !cancel {
                DispatchQueue.main.async(execute: theClosure)
            }
        }
        closure = nil
        result = nil
    }

    result = delayClosure

    delay(interval) {
        if let delayedClosure = result {
            delayedClosure(false)
        }
    }

    return result
}

public func cancelDelayTask(_ task: DelayTask?) {
    task?(true)
}
