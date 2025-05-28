//
//  APIService.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 4/29/25.
//

import Foundation

// Function to send the POST request
func sendQuery(query: String) async throws -> [String: String?] {
    // Construct the payload
    let payload = Payload(
        query: query,
        modelType: "gemini",
        modelConfig: ModelConfig(model: "gemini-2.0-flash")
    )
    
    // Encode the payload to JSON
    let jsonData = try JSONEncoder().encode(payload)
    
    // Create the URL and request
    let endpoint = Bundle.main.object(forInfoDictionaryKey: "API_ENDPOINT") as? String ?? ""
    guard let url = URL(string: endpoint) else {
        throw APIServiceError.invalidURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    
    // Send the request
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
    
        // Check the response status
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIServiceError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        // Decode the response
        let responseData = try JSONDecoder().decode(LLMResponse.self, from: data)

        // Return the data dictionary
        return responseData.data
        
    } catch let error as URLError {
        switch error.code {
        case .notConnectedToInternet:
            throw APIServiceError.noInternetConnection
        case .timedOut:
            throw APIServiceError.timeout
        default:
            throw APIServiceError.unknown(error)
        }
    } catch {
        throw APIServiceError.decodingError
    }
}
