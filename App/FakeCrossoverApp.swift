import SwiftUI

@main
struct FakeCrossoverApp: App {
    @StateObject private var bottleStore: BottleStore
    @StateObject private var runtimeManager: RuntimeManager
    @StateObject private var taskRunner: TaskRunner
    @StateObject private var controller: AppController

    init() {
        let store = BottleStore()
        let runtime = RuntimeManager()
        let runner = TaskRunner()
        _bottleStore = StateObject(wrappedValue: store)
        _runtimeManager = StateObject(wrappedValue: runtime)
        _taskRunner = StateObject(wrappedValue: runner)
        _controller = StateObject(wrappedValue: AppController(store: store, runtimeManager: runtime, taskRunner: runner))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bottleStore)
                .environmentObject(runtimeManager)
                .environmentObject(taskRunner)
                .environmentObject(controller)
        }
    }
}
