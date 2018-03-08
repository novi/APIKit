import Foundation

extension URLSessionTask: SessionTask {

}

private var dataTaskResponseBufferKey = 0
private var taskAssociatedObjectCompletionHandlerKey = 0
private var taskAssociatedObjectProgressHandlerKey = 0

/// `URLSessionAdapter` connects `URLSession` with `Session`.
///
/// If you want to add custom behavior of `URLSession` by implementing delegate methods defined in
/// `URLSessionDelegate` and related protocols, define a subclass of `URLSessionAdapter` and implement
/// delegate methods that you want to implement. Since `URLSessionAdapter` also implements delegate methods
/// `URLSession(_:task: didCompleteWithError:)` and `URLSession(_:dataTask:didReceiveData:)`, you have to call
/// `super` in these methods if you implement them.
open class URLSessionAdapter: NSObject, SessionAdapter, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    internal final class TaskProperty {
        var buffer: Data
        let handler: (Data?, URLResponse?, Error?) -> Void
        
        init(buffer: Data = Data(), handler: @escaping (Data?, URLResponse?, Error?) -> Void) {
            self.buffer = buffer
            self.handler = handler
        }
    }

    internal var taskProperties = [Int: TaskProperty]()

    /// The undelying `URLSession` instance.
    open var urlSession: URLSession!

    /// Returns `URLSessionAdapter` initialized with `URLSessionConfiguration`.
    public init(configuration: URLSessionConfiguration) {
        super.init()
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Creates `URLSessionDataTask` instance using `dataTaskWithRequest(_:completionHandler:)`.
    open func createTask(with URLRequest: URLRequest, progressHandler: @escaping (Int64, Int64, Int64) -> Void, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> SessionTask {
        let task = urlSession.dataTask(with: URLRequest)
        taskProperties[task.taskIdentifier] = TaskProperty(handler: completionHandler)

        //setBuffer(NSMutableData(), forTask: task)
        //setHandler(completionHandler, forTask: task)
        //setProgressHandler(progressHandler, forTask: task)

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
#if os(macOS) 
    private func setBuffer(_ buffer: NSMutableData, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &dataTaskResponseBufferKey, buffer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func buffer(for task: URLSessionTask) -> NSMutableData? {
        return objc_getAssociatedObject(task, &dataTaskResponseBufferKey) as? NSMutableData
    }

    private func setHandler(_ handler: @escaping (Data?, URLResponse?, Error?) -> Void, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &taskAssociatedObjectCompletionHandlerKey, handler as Any, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func handler(for task: URLSessionTask) -> ((Data?, URLResponse?, Error?) -> Void)? {
        return objc_getAssociatedObject(task, &taskAssociatedObjectCompletionHandlerKey) as? (Data?, URLResponse?, Error?) -> Void
    }

    private func setProgressHandler(_ progressHandler: @escaping (Int64, Int64, Int64) -> Void, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &taskAssociatedObjectProgressHandlerKey, progressHandler as Any, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func progressHandler(for task: URLSessionTask) -> ((Int64, Int64, Int64) -> Void)? {
        return objc_getAssociatedObject(task, &taskAssociatedObjectProgressHandlerKey) as? (Int64, Int64, Int64) -> Void
    }
#endif
    // MARK: URLSessionTaskDelegate
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskProperty = taskProperties[task.taskIdentifier]
        taskProperty?.handler(taskProperty?.buffer, task.response, error)

        taskProperties[task.taskIdentifier] = nil
    }

    // MARK: URLSessionDataDelegate
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskProperty = taskProperties[dataTask.taskIdentifier]
        taskProperty?.buffer.append(data)
    }

    // MARK: URLSessionDataDelegate
    open func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        //progressHandler(for: task)?(bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }
}
