import Foundation

struct CursorMe: Codable {
    var apiKeyName: String?
    var userId: Int?
    var createdAt: String?
    var userEmail: String?
    var userFirstName: String?
    var userLastName: String?
}

struct CursorModel: Codable, Identifiable {
    var id: String
    var displayName: String?
}

struct CursorModelsResponse: Codable {
    var items: [CursorModel]
}

struct CursorAgent: Codable, Identifiable {
    var id: String
    var name: String?
    var status: String?
    var url: String?
    var latestRunId: String?
}

struct CursorAgentsResponse: Codable {
    var items: [CursorAgent]
}

struct CursorCreateAgentResponse: Codable {
    var agent: CursorAgent?
    var id: String?
    var name: String?
    var status: String?
    var url: String?
}

struct CursorInitSnapshot {
    var me: CursorMe
    var models: [CursorModel]
    var agents: [CursorAgent]
    var checkedAt: Date
}

enum CursorAPIError: LocalizedError {
    case missingKey
    case http(Int, String)
    case decode

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Нет ключа Cursor API. Положите его в .env или Keychain."
        case .http(let code, _):
            return "Cursor API ответил \(code)."
        case .decode:
            return "Не удалось разобрать ответ Cursor API."
        }
    }
}

struct CursorAPI {
    var baseURL = URL(string: "https://api.cursor.com/v1")!
    var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }()

    func initSession(apiKey: String) async throws -> CursorInitSnapshot {
        async let me: CursorMe = get("me", apiKey: apiKey)
        async let models: CursorModelsResponse = get("models", apiKey: apiKey)
        async let agents: CursorAgentsResponse = get("agents", apiKey: apiKey, query: ["limit": "5"])
        let (meValue, modelsValue, agentsValue) = try await (me, models, agents)
        return CursorInitSnapshot(me: meValue, models: modelsValue.items, agents: agentsValue.items, checkedAt: Date())
    }

    func createAgent(apiKey: String, prompt: String, githubURL: String?, modelID: String?) async throws -> CursorCreateAgentResponse {
        var body: [String: Any] = [
            "prompt": ["text": prompt],
            "name": String(prompt.prefix(80))
        ]
        if let modelID, !modelID.isEmpty, modelID != "default" {
            body["model"] = ["id": modelID]
        }
        if let githubURL, let url = URL(string: githubURL), url.host != nil {
            body["repos"] = [["url": githubURL]]
        }
        return try await post("agents", apiKey: apiKey, json: body)
    }

    private func get<T: Decodable>(_ path: String, apiKey: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyAuth(&request, apiKey: apiKey)
        return try await send(request)
    }

    private func post<T: Decodable>(_ path: String, apiKey: String, json: [String: Any]) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request, apiKey: apiKey)
        request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])
        return try await send(request)
    }

    private func applyAuth(_ request: inout URLRequest, apiKey: String) {
        let raw = "\(apiKey):"
        let encoded = Data(raw.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        request.setValue("BussinessRunner/0.1", forHTTPHeaderField: "User-Agent")
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw CursorAPIError.http(code, String(snippet.prefix(240)))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CursorAPIError.decode
        }
    }
}
