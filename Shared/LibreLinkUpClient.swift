import CryptoKit
import Foundation

struct LibreCredentials: Codable, Equatable, Sendable {
    var email: String
    var password: String
}

/// A logged-in LibreLinkUp session. Kept in the Keychain so background
/// refreshes don't log in every time (LibreLinkUp rate-limits logins).
struct LibreSession: Codable, Sendable {
    var host: String
    var token: String
    var expires: Date
    var accountId: String
    var patientId: String?
}

enum LibreLinkUpError: LocalizedError, Equatable {
    case notLoggedIn
    case badCredentials
    case termsNotAccepted
    case noConnections
    case unauthorized
    case rateLimited
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: "Open Sugar Link and log in first."
        case .badCredentials: "Wrong LibreLinkUp email or password."
        case .termsNotAccepted: "Open the LibreLinkUp app and accept the terms, then try again."
        case .noConnections: "This LibreLinkUp account doesn't follow anyone yet. Invite it from your Libre 3 app."
        case .unauthorized: "LibreLinkUp session expired."
        case .rateLimited: "LibreLinkUp is busy. Trying again shortly."
        case .server(let message): "LibreLinkUp: \(message)"
        }
    }
}

/// Client for the unofficial LibreLinkUp follower API.
actor LibreLinkUpClient {
    /// LibreLinkUp rejects old app versions. Bump this if logins start failing
    /// with a version error (check the current LibreLinkUp version in the App Store).
    static let appVersion = "4.16.0"
    static let defaultHost = "api.libreview.io"

    private let credentials: LibreCredentials
    private let urlSession: URLSession
    private(set) var session: LibreSession?

    init(credentials: LibreCredentials, session: LibreSession?, urlSession: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
        self.urlSession = urlSession
    }

    /// Current reading and the last ~12 hours of history.
    func fetch() async throws -> (current: GlucoseReading, history: [GlucoseReading]) {
        do {
            return try await fetchGraph()
        } catch LibreLinkUpError.unauthorized {
            session = nil
            return try await fetchGraph()
        }
    }

    // MARK: - Requests

    private func fetchGraph() async throws -> (current: GlucoseReading, history: [GlucoseReading]) {
        var session = try await validSession()
        if session.patientId == nil {
            session.patientId = try await fetchPatientId(session)
            self.session = session
        }
        let response: Envelope<GraphData> = try await request(
            "/llu/connections/\(session.patientId!)/graph", session: session)
        guard let data = response.data else { throw LibreLinkUpError.server("No glucose data") }

        let currentMeasurement = data.connection.glucoseMeasurement
        guard let current = currentMeasurement.reading else {
            throw LibreLinkUpError.server("No current reading")
        }
        let history = (data.graphData ?? []).compactMap(\.reading)
        return (current, history)
    }

    private func validSession() async throws -> LibreSession {
        if let session, session.expires > .now.addingTimeInterval(3600) {
            return session
        }
        let session = try await login(host: session?.host ?? Self.defaultHost, followRedirect: true)
        self.session = session
        return session
    }

    private func login(host: String, followRedirect: Bool) async throws -> LibreSession {
        let body = try JSONEncoder().encode(["email": credentials.email, "password": credentials.password])
        let response: Envelope<LoginData> = try await send(
            host: host, path: "/llu/auth/login", method: "POST", body: body, session: nil)

        switch response.status {
        case 0: break
        case 2: throw LibreLinkUpError.badCredentials
        case 4: throw LibreLinkUpError.termsNotAccepted
        default: throw LibreLinkUpError.server(response.error?.message ?? "Login failed (\(response.status))")
        }
        guard let data = response.data else { throw LibreLinkUpError.server("Empty login response") }

        if data.redirect == true, let region = data.region {
            guard followRedirect else { throw LibreLinkUpError.server("Region redirect loop") }
            return try await login(host: Self.host(forRegion: region), followRedirect: false)
        }
        guard let user = data.user, let ticket = data.authTicket else {
            if data.step != nil { throw LibreLinkUpError.termsNotAccepted }
            throw LibreLinkUpError.server("Unexpected login response")
        }
        return LibreSession(
            host: host,
            token: ticket.token,
            expires: Date(timeIntervalSince1970: ticket.expires),
            accountId: Self.sha256(user.id),
            patientId: nil)
    }

    private func fetchPatientId(_ session: LibreSession) async throws -> String {
        let response: Envelope<[Connection]> = try await request("/llu/connections", session: session)
        guard let first = response.data?.first else { throw LibreLinkUpError.noConnections }
        return first.patientId
    }

    // MARK: - HTTP

    private func request<T: Decodable>(_ path: String, session: LibreSession) async throws -> Envelope<T> {
        let response: Envelope<T> = try await send(
            host: session.host, path: path, method: "GET", body: nil, session: session)
        if response.status != 0 {
            if response.status == 401 || response.error?.message == "notAuthenticated" {
                throw LibreLinkUpError.unauthorized
            }
            throw LibreLinkUpError.server(response.error?.message ?? "Error \(response.status)")
        }
        return response
    }

    private func send<T: Decodable>(
        host: String, path: String, method: String, body: Data?, session: LibreSession?
    ) async throws -> Envelope<T> {
        var request = URLRequest(url: URL(string: "https://\(host)\(path)")!)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("llu.ios", forHTTPHeaderField: "product")
        request.setValue(Self.appVersion, forHTTPHeaderField: "version")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let session {
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
            request.setValue(session.accountId, forHTTPHeaderField: "Account-Id")
        }

        let (data, urlResponse) = try await urlSession.data(for: request)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        switch statusCode {
        case 401: throw LibreLinkUpError.unauthorized
        case 429, 430: throw LibreLinkUpError.rateLimited
        case 500...: throw LibreLinkUpError.server("Server error \(statusCode)")
        default: break
        }
        do {
            return try JSONDecoder().decode(Envelope<T>.self, from: data)
        } catch {
            throw LibreLinkUpError.server("Unexpected response (\(statusCode))")
        }
    }

    // MARK: - Helpers

    static func host(forRegion region: String) -> String {
        switch region.lowercased() {
        case "ru": "api.libreview.ru"
        case "cn": "api-cn.myfreestyle.cn"
        default: "api-\(region.lowercased()).libreview.io"
        }
    }

    static func sha256(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// LibreLinkUp timestamps look like "10/4/2026 7:12:34 AM". `FactoryTimestamp` is UTC.
    static func parseTimestamp(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        return formatter.date(from: string)
    }
}

// MARK: - Response types

private struct Envelope<T: Decodable>: Decodable {
    var status: Int
    var data: T?
    var error: APIError?

    struct APIError: Decodable { var message: String? }
}

private struct LoginData: Decodable {
    struct User: Decodable { var id: String }
    struct AuthTicket: Decodable { var token: String; var expires: TimeInterval }
    struct Step: Decodable { var type: String? }

    var user: User?
    var authTicket: AuthTicket?
    var redirect: Bool?
    var region: String?
    var step: Step?
}

private struct Connection: Decodable {
    var patientId: String
}

private struct Measurement: Decodable {
    var FactoryTimestamp: String?
    var ValueInMgPerDl: Double?
    var TrendArrow: Int?

    var reading: GlucoseReading? {
        guard let value = ValueInMgPerDl,
              let timestamp = FactoryTimestamp,
              let date = LibreLinkUpClient.parseTimestamp(timestamp)
        else { return nil }
        return GlucoseReading(mgdl: value, date: date, trend: Trend(rawValue: TrendArrow ?? 0) ?? .unknown)
    }
}

private struct GraphData: Decodable {
    struct GraphConnection: Decodable { var glucoseMeasurement: Measurement }

    var connection: GraphConnection
    var graphData: [Measurement]?
}
