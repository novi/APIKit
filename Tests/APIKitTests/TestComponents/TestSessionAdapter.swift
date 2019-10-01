import Foundation
import APIKit

class TestSessionAdapter: SessionAdapter {
    enum Error: Swift.Error {
        case cancelled
    }

    var data: Data?
    var urlResponse: URLResponse?
    var error: Error?

    private class Runner {
        weak var adapter: TestSessionAdapter?

        @objc func run() {
            adapter?.executeAllTasks()
        }
    }

    private var tasks = [TestSessionTask]()
    private let runner: Runner
    private let timer: Timer

    init(data: Data? = Data(), urlResponse: URLResponse? = HTTPURLResponse(url: NSURL(string: "")! as URL, statusCode: 200, httpVersion: nil, headerFields: nil), error: Error? = nil) {
        self.data = data
        self.urlResponse = urlResponse
        self.error = error

        let runner = Runner()
        self.runner = runner
        
        #if canImport(Darwin)
        self.timer = Timer.scheduledTimer(timeInterval: 0.001,
            target: runner,
            selector: #selector(Runner.run),
            userInfo: nil,
            repeats: true)
        #else
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true, block: { [weak runner] _ in
            runner?.run()
        })
        #endif

        self.runner.adapter = self
    }

    func executeAllTasks() {
        for task in tasks {
            if task.cancelled {
                task.handler(nil, nil, Error.cancelled)
            } else {
                task.handler(data, urlResponse, error)
            }
        }

        tasks = []
    }

    func createTask(with URLRequest: URLRequest, handler: @escaping (Data?, URLResponse?, Swift.Error?) -> Void) -> SessionTask {
        let task = TestSessionTask(handler: handler)
        tasks.append(task)

        return task
    }

    func getTasks(with handler: @escaping ([SessionTask]) -> Void) {
        handler(tasks.map { $0 })
    }
}
