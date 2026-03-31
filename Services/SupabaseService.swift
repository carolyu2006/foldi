import Foundation
import AppKit

// MARK: - Config
// Only the anon (publishable) key lives here — safe to ship.
// The service-role key NEVER appears in app code.
enum SupabaseConfig {
    static let projectURL = "https://jjlilpfuofhlhjnvekzz.supabase.co"
    static let anonKey    = "sb_publishable_xM6pZshfIhju8rbWBSfvrw_wDXXqOJr"
    static let bucket     = "icon-packs"
}

// MARK: - Auth models

struct AuthSession: Codable {
    let accessToken:  String
    let refreshToken: String
    let user:         AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Codable {
    let id:           String
    let email:        String
    let userMetadata: AuthUserMetadata?

    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
    }
}

struct AuthUserMetadata: Codable {
    let username:    String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
    }
}

// MARK: - Remote pack model

struct RemoteIconPack: Identifiable, Codable {
    let id:     String
    let name:   String
    let author: String
    let tags:   [String]?
    let icons:  [String]   // storage object paths e.g. "glass/glass_1.png"
    let status: String?    // "pending" | "approved" | "rejected"
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, author, tags, icons, status
        case userId = "user_id"
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case badURL
    case httpError(Int, String)
    case decodingError(Error)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .badURL:                   return "Invalid Supabase URL."
        case .httpError(let c, let m):  return "HTTP \(c): \(m)"
        case .decodingError(let e):     return "Decode failed: \(e.localizedDescription)"
        case .notAuthenticated:         return "You must be signed in to do that."
        }
    }
}

// MARK: - Service

enum SupabaseService {

    // MARK: Auth ── sign in

    static func signIn(email: String, password: String) async throws -> AuthSession {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=password") else {
            throw SupabaseError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)

        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    // MARK: Auth ── refresh token

    static func refreshSession(refreshToken: String) async throws -> AuthSession {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=refresh_token") else {
            throw SupabaseError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)

        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    // MARK: Auth ── sign out

    static func signOut(accessToken: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/logout") else {
            throw SupabaseError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey,          forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",          forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)   // best-effort
    }

    // MARK: Database ── fetch packs

    /// Fetch approved icon packs.
    static func fetchIconPacks() async throws -> [RemoteIconPack] {
        let query = "\(SupabaseConfig.projectURL)/rest/v1/icon_packs?select=*&order=name&status=eq.approved"

        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.setValue(SupabaseConfig.anonKey,              forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)",  forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                  forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)

        do {
            return try JSONDecoder().decode([RemoteIconPack].self, from: data)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    // MARK: Storage ── public URL + fetch image

    static func publicURL(for path: String) -> URL? {
        URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/public/\(SupabaseConfig.bucket)/\(path)")
    }

    static func fetchImage(path: String) async throws -> NSImage {
        guard let url = publicURL(for: path) else { throw SupabaseError.badURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response, data: data)
        guard let image = NSImage(data: data) else {
            throw SupabaseError.httpError(0, "Could not decode image")
        }
        return image
    }

    // MARK: Upload ── requires authenticated user JWT

    /// Upload a single PNG to Storage using the signed-in user's access token.
    static func uploadIcon(data: Data, path: String, accessToken: String) async throws {
        guard let url = URL(string:
            "\(SupabaseConfig.projectURL)/storage/v1/object/\(SupabaseConfig.bucket)/\(path)"
        ) else { throw SupabaseError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("image/png",             forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (respData, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: respData)
    }

    /// Insert a new icon pack row (status defaults to 'pending' via DB default).
    static func insertIconPack(
        name: String,
        author: String,
        tags: [String],
        icons: [String],
        userId: String,
        accessToken: String
    ) async throws {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/icon_packs") else {
            throw SupabaseError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey,  forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal",        forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "name": name, "author": author,
            "tags": tags, "icons": icons,
            "user_id": userId, "status": "approved"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (respData, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: respData)
    }

    // MARK: User profile ── saved packs

    /// Fetch the array of saved pack IDs from the user's profile row.
    static func fetchUserSavedPackIds(userId: String, accessToken: String) async throws -> [String] {
        let query = "\(SupabaseConfig.projectURL)/rest/v1/profiles?select=saved_pack_ids&id=eq.\(userId)"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.setValue(SupabaseConfig.anonKey,          forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",          forHTTPHeaderField: "Authorization")
        req.setValue("application/json",               forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)

        struct ProfileRow: Decodable {
            let savedPackIds: [String]?
            enum CodingKeys: String, CodingKey { case savedPackIds = "saved_pack_ids" }
        }
        do {
            let rows = try JSONDecoder().decode([ProfileRow].self, from: data)
            return rows.first?.savedPackIds ?? []
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    // MARK: Saved packs table

    /// Fetch pack IDs saved by the user from the saved_packs table.
    static func fetchSavedPackIds(userId: String, accessToken: String) async throws -> [String] {
        let query = "\(SupabaseConfig.projectURL)/rest/v1/saved_packs?select=pack_id&user_id=eq.\(userId)"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.setValue(SupabaseConfig.anonKey,          forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",          forHTTPHeaderField: "Authorization")
        req.setValue("application/json",               forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        struct Row: Decodable { let packId: String; enum CodingKeys: String, CodingKey { case packId = "pack_id" } }
        do {
            return try JSONDecoder().decode([Row].self, from: data).map(\.packId)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    /// Add a pack to saved_packs (ignores duplicate).
    static func addSavedPack(userId: String, packId: String, accessToken: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/saved_packs") else {
            throw SupabaseError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey,                             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",                             forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                                  forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=ignore-duplicates,return=minimal",       forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId, "pack_id": packId])
        let (respData, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: respData)
    }

    // MARK: Wishlist table

    /// Fetch pack IDs in the user's wishlist.
    static func fetchWishlistPackIds(userId: String, accessToken: String) async throws -> [String] {
        let query = "\(SupabaseConfig.projectURL)/rest/v1/wishlist_items?select=pack_id&user_id=eq.\(userId)"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.setValue(SupabaseConfig.anonKey,    forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",   forHTTPHeaderField: "Authorization")
        req.setValue("application/json",        forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        struct Row: Decodable { let packId: String; enum CodingKeys: String, CodingKey { case packId = "pack_id" } }
        do {
            return try JSONDecoder().decode([Row].self, from: data).map(\.packId)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    /// Add a pack to wishlist_items (ignores duplicate).
    static func addWishlistItem(userId: String, packId: String, accessToken: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/wishlist_items") else {
            throw SupabaseError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey,                             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",                             forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                                  forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=ignore-duplicates,return=minimal",       forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId, "pack_id": packId])
        let (respData, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: respData)
    }

    /// Remove a pack from wishlist_items.
    static func removeWishlistItem(userId: String, packId: String, accessToken: String) async throws {
        let query = "\(SupabaseConfig.projectURL)/rest/v1/wishlist_items?user_id=eq.\(userId)&pack_id=eq.\(packId)"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(SupabaseConfig.anonKey,    forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",   forHTTPHeaderField: "Authorization")
        req.setValue("return=minimal",          forHTTPHeaderField: "Prefer")
        let (respData, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: respData)
    }

    /// Remove a pack from saved_packs.
    static func removeSavedPack(userId: String, packId: String, accessToken: String) async throws {
        let query = "\(SupabaseConfig.projectURL)/rest/v1/saved_packs?user_id=eq.\(userId)&pack_id=eq.\(packId)"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(SupabaseConfig.anonKey,          forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",          forHTTPHeaderField: "Authorization")
        req.setValue("return=minimal",                 forHTTPHeaderField: "Prefer")
        let (respData, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: respData)
    }

    /// Fetch approved packs by author name (case-insensitive).
    static func fetchPacksByAuthor(_ author: String) async throws -> [RemoteIconPack] {
        let encoded = author.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? author
        let query = "\(SupabaseConfig.projectURL)/rest/v1/icon_packs?select=*&author=ilike.\(encoded)&order=name"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.setValue(SupabaseConfig.anonKey,             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                 forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        do {
            return try JSONDecoder().decode([RemoteIconPack].self, from: data)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    /// Fetch all icon packs belonging to a specific user.
    static func fetchPacksByUserId(_ userId: String, accessToken: String) async throws -> [RemoteIconPack] {
        let query = "\(SupabaseConfig.projectURL)/rest/v1/icon_packs?select=*&user_id=eq.\(userId)&order=name"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.setValue(SupabaseConfig.anonKey,          forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",          forHTTPHeaderField: "Authorization")
        req.setValue("application/json",               forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)

        do {
            return try JSONDecoder().decode([RemoteIconPack].self, from: data)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    /// Fetch icon packs matching the given IDs.
    static func fetchPacksByIds(_ ids: [String], accessToken: String? = nil) async throws -> [RemoteIconPack] {
        guard !ids.isEmpty else { return [] }
        let idList = ids.joined(separator: ",")
        let query = "\(SupabaseConfig.projectURL)/rest/v1/icon_packs?select=*&id=in.(\(idList))"
        guard let url = URL(string: query) else { throw SupabaseError.badURL }
        var req = URLRequest(url: url)
        req.setValue(SupabaseConfig.anonKey,                                      forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken ?? SupabaseConfig.anonKey)",           forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                                          forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)

        do {
            return try JSONDecoder().decode([RemoteIconPack].self, from: data)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    /// Upsert saved_pack_ids into the user's profile row (creates the row if it doesn't exist).
    static func upsertSavedPackIds(userId: String, accessToken: String, ids: [String]) async throws {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/profiles") else {
            throw SupabaseError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey,                             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)",                             forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                                  forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=minimal",        forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["id": userId, "saved_pack_ids": ids])
        let (respData, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: respData)
    }

    // MARK: Helper

    static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SupabaseError.httpError(http.statusCode, msg)
        }
    }
}
