import Foundation
import UIKit

/// Screen-view analytics → self-hosted Umami (https://analytics.nextgensoft.co,
/// website "Callback"). One fire-and-forget POST per screen: no cookies, no
/// identifiers, nothing beyond the screen name plus app/OS version in the
/// User-Agent. Failures are ignored. Off by default; `CallbackApp` turns it on
/// for real runs only (never under XCTest, `--uitest`, or `--demo-seed`).
@MainActor
enum Analytics {
    static var enabled = false

    static func screen(_ name: String) {
        guard enabled else { return }
        var request = URLRequest(url: URL(string: "https://analytics.nextgensoft.co/api/send")!, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(
            #"{"type":"event","payload":{"website":"4789fcd8-0157-4a55-820d-87b6b67ab258","hostname":"cx.viz.callback","url":"/\#(name)","title":"\#(name)"}}"#.utf8
        )
        URLSession.shared.dataTask(with: request).resume()
    }

    /// Browser-shaped so Umami's bot filter keeps it; carries OS + app version.
    private static let userAgent: String = {
        let os = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) Callback/\(version)"
    }()
}
