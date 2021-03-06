//
// Copyright 2018 Wultra s.r.o.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions
// and limitations under the License.
//

import Foundation

public protocol CompletableInSpecificQueue {
    func assignCompletionDispatchQueue(_ queue: DispatchQueue?)
}

public extension LimeAuthSession {
    
    func addOperationToQueue(_ operation: Operation, serialized: Bool) -> Operation {
        let queue = serialized ? serializedQueue : concurrentQueue
        if let completableInSpecificQueue = operation as? CompletableInSpecificQueue {
            completableInSpecificQueue.assignCompletionDispatchQueue(operationCompletionQueue)
        }
        queue.addOperation(operation)
        return operation
    }
}
