import Foundation
import APIKit

class TestSessionTask: SessionTask {
    struct IdGenerator {
        private var currentId = 1
        
        public mutating func next() -> Int {
            currentId += 1
            return currentId
        }
    }
    
    static var idGenerator = IdGenerator()
    
    var taskIdentifier: Int
    var completionHandler: (Data?, URLResponse?, Error?) -> Void
    var progressHandler: (Int64, Int64, Int64) -> Void
    var cancelled = false

    init(progressHandler: @escaping  (Int64, Int64, Int64) -> Void, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.taskIdentifier = TestSessionTask.idGenerator.next()
        self.completionHandler = completionHandler
        self.progressHandler = progressHandler
    }

    func resume() {

    }

    func cancel() {
        cancelled = true
    }
}
