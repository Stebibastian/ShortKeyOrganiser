import Foundation

struct UpdateInfo {
    let version: String
    let pageURL: String
    let notes: String
}

/// Prüft die neueste GitHub-Release und vergleicht sie mit der eigenen Version.
/// Leichtgewichtig (nur die GitHub-API), kein externes Update-Framework.
enum UpdateChecker {
    private static let releasesAPI =
        "https://api.github.com/repos/Stebibastian/ShortKeyOrganiser/releases/latest"
    static let releasesPage =
        "https://github.com/Stebibastian/ShortKeyOrganiser/releases/latest"
    /// Holt + installiert die neueste notarisierte Version und startet sie neu.
    static let installCommand =
        "sleep 1; curl -fsSL https://raw.githubusercontent.com/Stebibastian/ShortKeyOrganiser/main/web-install.sh | bash"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Fragt die neueste Release ab. `completion` läuft auf dem Main-Thread:
    /// .success(info) = Update verfügbar, .success(nil) = bereits aktuell, .failure = Fehler.
    static func check(completion: @escaping (Result<UpdateInfo?, Error>) -> Void) {
        guard let url = URL(string: releasesAPI) else { completion(.success(nil)); return }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                if let error { completion(.failure(error)); return }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    completion(.success(nil)); return
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                let page = json["html_url"] as? String ?? releasesPage
                let notes = json["body"] as? String ?? ""
                let info = isNewer(latest, than: currentVersion)
                    ? UpdateInfo(version: latest, pageURL: page, notes: notes) : nil
                completion(.success(info))
            }
        }.resume()
    }

    /// Semver-Vergleich: ist `a` neuer als `b`? (z. B. "1.0.2" > "1.0.1")
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
