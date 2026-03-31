import Foundation
import Observation

// MARK: - Stored session (persisted as JSON in Keychain)

struct StoredSession: Codable {
    var accessToken:  String
    var refreshToken: String
    var userId:       String
    var email:        String
    var username:     String
    var displayName:  String?
}

// MARK: - Auth service

@Observable
final class AppAuthService {

    private(set) var session: StoredSession?

    var isSignedIn:   Bool    { session != nil }
    var username:     String  { session?.username    ?? "" }
    var displayName:  String  { session?.displayName ?? session?.username ?? "" }
    var accessToken:  String? { session?.accessToken }
    var userId:       String? { session?.userId }

    private let keychainKey = "foldi_auth_session_v1"

    init() { loadFromKeychain() }

    // MARK: Sign in

    @MainActor
    func signIn(email: String, password: String) async throws {
        let raw = try await SupabaseService.signIn(email: email, password: password)
        let stored = StoredSession(
            accessToken:  raw.accessToken,
            refreshToken: raw.refreshToken,
            userId:       raw.user.id,
            email:        raw.user.email,
            username:     raw.user.userMetadata?.username
                          ?? email.components(separatedBy: "@").first
                          ?? "designer",
            displayName:  raw.user.userMetadata?.displayName
        )
        session = stored
        saveToKeychain(stored)
    }

    // MARK: Refresh token

    /// Silently refresh the access token using the stored refresh token.
    /// If refresh fails (e.g. refresh token also expired), signs out automatically.
    @MainActor
    func refreshIfNeeded() async {
        guard let refreshToken = session?.refreshToken else { return }
        do {
            let raw = try await SupabaseService.refreshSession(refreshToken: refreshToken)
            let stored = StoredSession(
                accessToken:  raw.accessToken,
                refreshToken: raw.refreshToken,
                userId:       raw.user.id,
                email:        raw.user.email,
                username:     raw.user.userMetadata?.username
                              ?? raw.user.email.components(separatedBy: "@").first
                              ?? "designer",
                displayName:  raw.user.userMetadata?.displayName
            )
            session = stored
            saveToKeychain(stored)
        } catch {
            // Refresh token expired or invalid — clear the session
            session = nil
            KeychainHelper.delete(for: keychainKey)
        }
    }

    // MARK: Sign out

    @MainActor
    func signOut() async {
        if let token = session?.accessToken {
            try? await SupabaseService.signOut(accessToken: token)
        }
        session = nil
        KeychainHelper.delete(for: keychainKey)
    }

    // MARK: Keychain persistence

    private func loadFromKeychain() {
        guard let json  = KeychainHelper.load(for: keychainKey),
              let data  = json.data(using: .utf8),
              let stored = try? JSONDecoder().decode(StoredSession.self, from: data)
        else { return }
        session = stored
    }

    private func saveToKeychain(_ stored: StoredSession) {
        guard let data = try? JSONEncoder().encode(stored),
              let json = String(data: data, encoding: .utf8)
        else { return }
        KeychainHelper.save(json, for: keychainKey)
    }
}
