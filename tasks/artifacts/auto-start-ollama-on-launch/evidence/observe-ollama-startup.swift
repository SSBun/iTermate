import Foundation

/// Observes the production refresh path without launching the GUI or changing saved settings.
@main
struct OllamaStartupObservation {
    @MainActor
    static func main() async throws {
        let service = LocalLLMService()
        for index in 1...2 {
            service.refresh()
            while service.isBusy {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            print("refresh=\(index) ready=\(service.isReady) status=\(service.status)")
        }
        service.stop()
        print("request cancelled; shared server left running")
    }
}
