import Foundation
import AppKit

// Top-level C function — can't capture context
private func crashHandler(_ exception: NSException) {
    let name = exception.name.rawValue
    let reason = exception.reason ?? "Unknown"
    let stack = exception.callStackSymbols.joined(separator: "\n")
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

    let title = "Crash: \(name)"
    let body = """
    **App Version:** \(appVersion)
    **macOS:** \(osVersion)
    **Date:** \(Date())

    **Exception:** \(name)
    **Reason:** \(reason)

    **Stack Trace:**
    ```
    \(stack)
    ```
    """

    // Save for next launch — can't reliably open mailto during crash
    let subject = "[Zen Crash] \(title)"
    let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body

    if let url = URL(string: "mailto:lukas@mitthjarta.se?subject=\(encodedSubject)&body=\(encodedBody)") {
        UserDefaults.standard.set(url.absoluteString, forKey: "pendingCrashReport")
    }

    // Also save the raw crash info for GitHub issue creation on next launch
    let crashInfo: [String: String] = ["title": title, "body": body]
    if let data = try? JSONEncoder().encode(crashInfo) {
        UserDefaults.standard.set(data, forKey: "pendingCrashData")
    }
}

/// Catches uncaught exceptions and reports them on next launch.
@MainActor
final class CrashReporter {
    static func install() {
        NSSetUncaughtExceptionHandler(crashHandler)
    }

    /// Call on app launch to send any pending crash report from last session
    static func sendPendingReport() {
        // Try GitHub issue first
        if let data = UserDefaults.standard.data(forKey: "pendingCrashData"),
           let crashInfo = try? JSONDecoder().decode([String: String].self, from: data),
           let title = crashInfo["title"],
           let body = crashInfo["body"] {
            UserDefaults.standard.removeObject(forKey: "pendingCrashData")
            createGitHubIssue(title: title, body: body)
        }

        // Also open email if saved
        if let urlString = UserDefaults.standard.string(forKey: "pendingCrashReport"),
           let url = URL(string: urlString) {
            UserDefaults.standard.removeObject(forKey: "pendingCrashReport")
            NSWorkspace.shared.open(url)
        }
    }

    private static func createGitHubIssue(title: String, body: String) {
        guard let url = URL(string: "https://api.github.com/repos/mettafive/zen/issues") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let json: [String: Any] = [
            "title": title,
            "body": body,
            "labels": ["crash", "bug"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        URLSession.shared.dataTask(with: request).resume()
    }
}
