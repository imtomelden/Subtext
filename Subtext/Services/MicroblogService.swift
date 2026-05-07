import Foundation

/// Micropub network calls for Micro.blog. Actor-isolated to prevent concurrent
/// read/write races.
actor MicroblogService {

    // MARK: - Errors

    enum MicroblogError: LocalizedError {
        case missingCredentials
        case httpError(Int)
        case malformedResponse(String)
        case decodingFailed(String)
        case encodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingCredentials:
                "Micro.blog token or page URL is not configured."
            case .httpError(let code):
                "Micro.blog returned HTTP \(code)."
            case .malformedResponse(let detail):
                "Unexpected Micro.blog response: \(detail)"
            case .decodingFailed(let detail):
                "Could not decode splash content from Micro.blog: \(detail)"
            case .encodingFailed(let detail):
                "Could not encode splash content: \(detail)"
            }
        }
    }

    private let micropubURL = URL(string: "https://micro.blog/micropub")!
    private let timeout: TimeInterval = 8

    // MARK: - Read

    func fetchSplash(token: String, pageURL: String) async throws -> SplashContent {
        var components = URLComponents(url: micropubURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "source"),
            URLQueryItem(name: "url", value: pageURL),
        ]
        guard let url = components.url else {
            throw MicroblogError.malformedResponse("Could not construct source query URL")
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try assertHTTP(response)

        // Response: { "properties": { "content": ["<json-string>"] } }
        let source = try JSONDecoder().decode(MicropubSourceResponse.self, from: data)
        guard let rawJSON = source.properties.content.first else {
            throw MicroblogError.malformedResponse("properties.content is empty")
        }
        guard let jsonData = rawJSON.data(using: .utf8) else {
            throw MicroblogError.malformedResponse("content is not valid UTF-8")
        }
        do {
            return try JSONDecoder().decode(SplashContent.self, from: jsonData)
        } catch {
            throw MicroblogError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Update (existing page)

    func updateSplash(_ content: SplashContent, token: String, pageURL: String) async throws {
        let jsonString = try encodeSplash(content)
        let body: [String: Any] = [
            "action": "update",
            "url": pageURL,
            "replace": ["content": [jsonString]],
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: micropubURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (_, response) = try await URLSession.shared.data(for: request)
        try assertHTTP(response)
    }

    // MARK: - Create (one-time migration)

    /// Creates the Micro.blog page and returns the URL from the Location header.
    func createSplashPage(_ content: SplashContent, slug: String, token: String) async throws -> String {
        let jsonString = try encodeSplash(content)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "h", value: "entry"),
            URLQueryItem(name: "name", value: slug),
            URLQueryItem(name: "content", value: jsonString),
            URLQueryItem(name: "mp-channel", value: "pages"),
        ]
        let bodyString = components.percentEncodedQuery ?? ""

        var request = URLRequest(url: micropubURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(bodyString.utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        try assertHTTP(response)

        guard let http = response as? HTTPURLResponse,
              let location = http.value(forHTTPHeaderField: "Location")
        else {
            throw MicroblogError.malformedResponse("No Location header in create response")
        }
        return location
    }

    // MARK: - Helpers

    private func assertHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw MicroblogError.httpError(http.statusCode)
        }
    }

    private func encodeSplash(_ content: SplashContent) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            let data = try encoder.encode(content)
            guard let string = String(data: data, encoding: .utf8) else {
                throw MicroblogError.encodingFailed("UTF-8 conversion failed")
            }
            return string
        } catch let e as MicroblogError {
            throw e
        } catch {
            throw MicroblogError.encodingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Response types

private struct MicropubSourceResponse: Decodable {
    struct Properties: Decodable {
        let content: [String]
    }
    let properties: Properties
}
