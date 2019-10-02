import Foundation

#if !canImport(ObjectiveC) && canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif

extension URLSessionTask: SessionTask {

}

#if !canImport(ObjectiveC)
fileprivate final class TaskAttribute {
    var buffer: NSMutableData
    let handler: (Data?, URLResponse?, Error?) -> Void
    
    init(buffer: NSMutableData = NSMutableData(), handler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.buffer = buffer
        self.handler = handler
    }
}
#endif

private var dataTaskResponseBufferKey = 0
private var taskAssociatedObjectCompletionHandlerKey = 0

/// `URLSessionAdapter` connects `URLSession` with `Session`.
///
/// If you want to add custom behavior of `URLSession` by implementing delegate methods defined in
/// `URLSessionDelegate` and related protocols, define a subclass of `URLSessionAdapter` and implement
/// delegate methods that you want to implement. Since `URLSessionAdapter` also implements delegate methods
/// `URLSession(_:task: didCompleteWithError:)` and `URLSession(_:dataTask:didReceiveData:)`, you have to call
/// `super` in these methods if you implement them.
open class URLSessionAdapter: NSObject, SessionAdapter, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    /// The undelying `URLSession` instance.
    open var urlSession: URLSession!

    /// Returns `URLSessionAdapter` initialized with `URLSessionConfiguration`.
    public init(configuration: URLSessionConfiguration) {
        super.init()
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Creates `URLSessionDataTask` instance using `dataTaskWithRequest(_:completionHandler:)`.
    open func createTask(with URLRequest: URLRequest, handler: @escaping (Data?, URLResponse?, Error?) -> Void) -> SessionTask {
        let task = urlSession.dataTask(with: URLRequest)

        #if canImport(ObjectiveC)
        setBuffer(NSMutableData(), forTask: task)
        setHandler(handler, forTask: task)
        #else
        tasksAttributeMutex.sync {
            tasksAttribute[task.taskIdentifier] = TaskAttribute(handler: handler)
        }
        #endif

        return task
    }

    /// Aggregates `URLSessionTask` instances in `URLSession` using `getTasksWithCompletionHandler(_:)`.
    open func getTasks(with handler: @escaping ([SessionTask]) -> Void) {
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            let allTasks = dataTasks as [URLSessionTask]
                + uploadTasks as [URLSessionTask]
                + downloadTasks as [URLSessionTask]

            handler(allTasks.map { $0 })
        }
    }
    
    #if !canImport(ObjectiveC)
    private var tasksAttribute = [Int: TaskAttribute]()
    private var tasksAttributeMutex = Mutex()
    #endif

    #if canImport(ObjectiveC)
    private func setBuffer(_ buffer: NSMutableData, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &dataTaskResponseBufferKey, buffer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func setHandler(_ handler: @escaping (Data?, URLResponse?, Error?) -> Void, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &taskAssociatedObjectCompletionHandlerKey, handler as Any, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    #endif

    private func buffer(for task: URLSessionTask) -> NSMutableData? {
        #if canImport(ObjectiveC)
        return objc_getAssociatedObject(task, &dataTaskResponseBufferKey) as? NSMutableData
        #else
        return tasksAttributeMutex.sync {
            tasksAttribute[task.taskIdentifier]?.buffer
        }
        #endif
    }
    
    private func handler(for task: URLSessionTask) -> ((Data?, URLResponse?, Error?) -> Void)? {
        #if canImport(ObjectiveC)
        return objc_getAssociatedObject(task, &taskAssociatedObjectCompletionHandlerKey) as? (Data?, URLResponse?, Error?) -> Void
        #else
        return tasksAttributeMutex.sync {
            tasksAttribute[task.taskIdentifier]?.handler
        }
        #endif
    }

    // MARK: URLSessionTaskDelegate
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        handler(for: task)?(buffer(for: task) as Data?, task.response, error)
        #if !canImport(ObjectiveC)
        tasksAttributeMutex.sync {
            tasksAttribute.removeValue(forKey: task.taskIdentifier)
        }
        #endif
    }

    // MARK: URLSessionDataDelegate
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer(for: dataTask)?.append(data)
    }
}

#if !canImport(ObjectiveC)
final class Mutex {
    private var mutex = pthread_mutex_t()
    init() {
        pthread_mutex_init(&mutex, nil)
    }
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    private func lock() {
        pthread_mutex_lock(&mutex)
    }
    private func unlock() {
        pthread_mutex_unlock(&mutex)
    }
    @discardableResult func sync<T>(_ block: () -> T) -> T {
        lock()
        let result = block()
        unlock()
        return result
    }
}
#endif
