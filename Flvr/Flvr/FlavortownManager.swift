//
//  FlavortownManager.swift
//  Flvr
//

import Foundation
import SwiftUI

/// A helper type that can decode an Int even if the API returns it as a String
struct FlexibleInt: Codable, Hashable {
    let value: Int
    
    init(value: Int) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let stringValue = try? container.decode(String.self), let intValue = Int(stringValue) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = Int(doubleValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected Int, String-Int, or Double")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct Project: Codable, Identifiable {
    let id: FlexibleInt
    let title: String?
    let description: String?
    let repoUrl: String?
    let demoUrl: String?
    let readmeUrl: String?
    let devlogIds: [FlexibleInt]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case repoUrl = "repo_url"
        case demoUrl = "demo_url"
        case readmeUrl = "readme_url"
        case devlogIds = "devlog_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProjectResponse: Codable {
    let projects: [Project]
}

struct Devlog: Codable, Identifiable {
    let id: FlexibleInt
    let body: String?
    let commentsCount: Int?
    let durationSeconds: Int?
    let likesCount: Int?
    let scrapbookUrl: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, body
        case commentsCount = "comments_count"
        case durationSeconds = "duration_seconds"
        case likesCount = "likes_count"
        case scrapbookUrl = "scrapbook_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TicketCost: Codable {
    let baseCost: FlexibleInt?
    
    enum CodingKeys: String, CodingKey {
        case baseCost = "base_cost"
    }
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if let intValue = try? container.decode(Int.self) {
                self.baseCost = FlexibleInt(value: intValue)
                return
            } else if let doubleValue = try? container.decode(Double.self) {
                self.baseCost = FlexibleInt(value: Int(doubleValue))
                return
            }
        }
        
        let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
        self.baseCost = try? keyedContainer.decode(FlexibleInt.self, forKey: .baseCost)
    }
}

struct StoreItem: Codable, Identifiable {
    let id: FlexibleInt
    let name: String?
    let description: String?
    let stock: FlexibleInt?
    let type: String?
    let imageUrl: String?
    let ticketCost: TicketCost?

    enum CodingKeys: String, CodingKey {
        case id, name, description, stock, type
        case imageUrl = "image_url"
        case ticketCost = "ticket_cost"
    }
}

struct User: Codable, Identifiable {
    let id: FlexibleInt
    let slackId: String?
    let displayName: String?
    let avatar: String?
    let projectIds: [FlexibleInt]?
    let cookies: Int?

    enum CodingKeys: String, CodingKey {
        case id, displayName = "display_name", avatar, cookies
        case slackId = "slack_id"
        case projectIds = "project_ids"
    }
}

struct UserResponse: Codable {
    let users: [User]
}

struct StoreResponse: Codable {
    let items: [StoreItem]
    
    enum CodingKeys: String, CodingKey {
        case items
        case storeItems = "store_items"
        case store
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try? container.decode([StoreItem].self, forKey: .items) {
            self.items = items
        } else if let items = try? container.decode([StoreItem].self, forKey: .storeItems) {
            self.items = items
        } else if let items = try? container.decode([StoreItem].self, forKey: .store) {
            self.items = items
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Could not find store items array"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
    }
}

struct DevlogResponse: Codable {
    let devlogs: [Devlog]
}

@Observable
class FlavortownManager {
    var projects: [Project] = []
    var devlogs: [Int: [Devlog]] = [:] // projectIdValue: [Devlog]
    var storeItems: [StoreItem] = []
    var users: [User] = []
    
    var showDevlogInfo = false
    var isFetching = false
    var lastUpdated: Date?
    var tabErrors: [Tab: String] = [:]
    
    // User Configuration
    var apiKey: String = UserDefaults.standard.string(forKey: "flvr_api_key") ?? "" {
        didSet { 
            UserDefaults.standard.set(apiKey, forKey: "flvr_api_key")
            triggerRefresh()
        }
    }
    
    var userId: String = UserDefaults.standard.string(forKey: "flvr_user_id") ?? "" {
        didSet { 
            UserDefaults.standard.set(userId, forKey: "flvr_user_id")
            triggerRefresh()
        }
    }
    
    private var refreshTask: Task<Void, Never>?
    private func triggerRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            if !Task.isCancelled {
                await fetchData()
            }
        }
    }
    
    var selectedProjectId: Int? = UserDefaults.standard.integer(forKey: "flvr_selected_project_id") == 0 ? nil : UserDefaults.standard.integer(forKey: "flvr_selected_project_id") {
        didSet {
            if let id = selectedProjectId {
                UserDefaults.standard.set(id, forKey: "flvr_selected_project_id")
            } else {
                UserDefaults.standard.removeObject(forKey: "flvr_selected_project_id")
            }
        }
    }
    
    var currentUser: User? {
        guard let idValue = Int(userId) else { return nil }
        return users.first { $0.id.value == idValue }
    }
    
    var userProjects: [Project] {
        guard let user = currentUser, let projectIds = user.projectIds else { return [] }
        let ids = Set(projectIds.map { $0.value })
        return projects.filter { ids.contains($0.id.value) }
    }
    
    var sortedProjects: [Project] {
        return projects.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }
    
    var sortedUsers: [User] {
        return users.sorted { ($0.displayName ?? "") < ($1.displayName ?? "") }
    }
    
    var totalHoursLogged: Double {
        guard let projectId = selectedProjectId, let logs = devlogs[projectId] else { return 0.0 }
        let totalSeconds = logs.compactMap { $0.durationSeconds }.reduce(0, +)
        return Double(totalSeconds) / 3600.0
    }

    var totalLoggedTimeText: String? {
        guard let projectId = selectedProjectId, let logs = devlogs[projectId] else { return nil }
        let totalSeconds = logs.compactMap { $0.durationSeconds }.reduce(0, +)
        if totalSeconds <= 0 { return nil }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    enum Tab: String, CaseIterable {
        case projects, store, users, settings
    }
    var selectedTab: Tab = .projects
    
    private let baseURL = "https://flavortown.hackclub.com/api/v1"
    private var timer: Timer?

    private func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15.0)
        request.addValue("true", forHTTPHeaderField: "X-Flavortown-Ext-2532")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add API Key if present
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            print("DEBUG: [APP] Using API Key starting with: \(key.prefix(4))...")
            // Standard Bearer token authentication
            if !key.lowercased().hasPrefix("bearer ") {
                request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            } else {
                request.addValue(key, forHTTPHeaderField: "Authorization")
            }
        } else {
            print("DEBUG: [APP] WARNING: No API Key found in settings.")
        }
        
        return request
    }

    func fetchData() async {
        await MainActor.run { 
            isFetching = true 
            tabErrors.removeAll()
        }
        
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchStoreItems() }
            
            if let id = Int(trimmedUserId) {
                // Targeted fetch for specific user
                group.addTask { 
                    await self.fetchSpecificUser(id: id)
                    // Clear previous projects if switching users
                    await MainActor.run { self.projects = [] }
                    // After user is fetched, fetch their projects
                    if let user = self.currentUser, let projectIds = user.projectIds {
                        await withTaskGroup(of: Void.self) { projectGroup in
                            for pid in projectIds {
                                projectGroup.addTask { await self.fetchSpecificProject(id: pid.value) }
                            }
                        }
                    }
                }
            } else {
                // Global fetch fallback
                group.addTask { await self.fetchProjects() }
                group.addTask { await self.fetchUsers() }
            }
        }
        
        // Fetch devlogs for the selected project if we have one
        if let selectedId = selectedProjectId {
            await fetchDevlogs(for: selectedId)
        }
        
        await MainActor.run {
            isFetching = false
            lastUpdated = Date()
        }
    }

    func fetchSpecificUser(id: Int) async {
        guard let url = URL(string: "\(baseURL)/users/\(id)") else { return }
        do {
            let request = createRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                if let user = try? decoder.decode(User.self, from: data) {
                    await MainActor.run { self.users = [user] }
                }
            }
        } catch {}
    }

    func fetchSpecificProject(id: Int) async {
        guard let url = URL(string: "\(baseURL)/projects/\(id)") else { return }
        do {
            let request = createRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                if let project = try? decoder.decode(Project.self, from: data) {
                    await MainActor.run {
                        if !self.projects.contains(where: { $0.id.value == project.id.value }) {
                            self.projects.append(project)
                        }
                    }
                }
            }
        } catch {}
    }

    func fetchProjects() async {
        guard let url = URL(string: "\(baseURL)/projects") else { return }
        print("DEBUG: [APP] Starting fetch projects from: \(url.absoluteString)")
        do {
            let request = createRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: [APP] Projects HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "No error body"
                    print("DEBUG: [APP] API Error Body: \(body)")
                    await MainActor.run {
                        self.tabErrors[.projects] = "API Error (\(httpResponse.statusCode)): \(body)"
                    }
                    return
                }
            }

            let decoder = JSONDecoder()
            if let projectResponse = try? decoder.decode(ProjectResponse.self, from: data) {
                await MainActor.run {
                    self.projects = projectResponse.projects
                }
            } else if let projects = try? decoder.decode([Project].self, from: data) {
                await MainActor.run {
                    self.projects = projects
                }
            } else {
                await MainActor.run {
                    self.tabErrors[.projects] = "Decoding failed."
                }
            }
        } catch {
            print("DEBUG: [APP] Network error fetching projects: \(error)")
            await MainActor.run {
                self.tabErrors[.projects] = "Network Error: \(error.localizedDescription)"
            }
        }
    }

    private func fetchDevlogsForProjects(_ projects: [Project]) async {
        // Fetch devlogs in parallel for the first 5 projects to avoid rate limiting
        let limitedProjects = Array(projects.prefix(5))
        await withTaskGroup(of: Void.self) { group in
            for project in limitedProjects {
                group.addTask {
                    await self.fetchDevlogs(for: project.id.value)
                }
            }
        }
    }

    func fetchStoreItems() async {
        guard let url = URL(string: "\(baseURL)/store") else { return }
        await MainActor.run { self.isFetching = true }
        
        do {
            let request = createRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.tabErrors[.store] = "Invalid response from server"
                    self.isFetching = false
                }
                return
            }
            
            if httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                await MainActor.run {
                    self.tabErrors[.store] = "API Error (\(httpResponse.statusCode)): \(body)"
                    self.isFetching = false
                }
                return
            }

            let decoder = JSONDecoder()
            do {
                if let storeResponse = try? decoder.decode(StoreResponse.self, from: data) {
                    await MainActor.run {
                        self.storeItems = storeResponse.items
                        self.tabErrors[.store] = nil
                        self.isFetching = false
                    }
                } else if let items = try? decoder.decode([StoreItem].self, from: data) {
                    await MainActor.run {
                        self.storeItems = items
                        self.tabErrors[.store] = nil
                        self.isFetching = false
                    }
                } else {
                    // Force decode to get the real error if both failed
                    _ = try decoder.decode([StoreItem].self, from: data)
                }
            } catch {
                let body = String(data: data, encoding: .utf8) ?? "No body"
                await MainActor.run {
                    self.tabErrors[.store] = "Decode Error: \(error.localizedDescription)\n\nResponse: \(body)"
                    self.isFetching = false
                }
            }
        } catch {
            await MainActor.run {
                self.tabErrors[.store] = "Connection Error: \(error.localizedDescription)"
                self.isFetching = false
            }
        }
    }

    func fetchUsers() async {
        guard let url = URL(string: "\(baseURL)/users") else { return }
        print("DEBUG: [APP] Starting fetch users from: \(url.absoluteString)")
        do {
            let request = createRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: [APP] Users HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "No error body"
                    print("DEBUG: [APP] Users API Error Body: \(body)")
                    await MainActor.run {
                        self.tabErrors[.users] = "API Error (\(httpResponse.statusCode)): \(body)"
                    }
                    return
                }
            }

            let decoder = JSONDecoder()
            if let userResponse = try? decoder.decode(UserResponse.self, from: data) {
                await MainActor.run {
                    self.users = userResponse.users
                }
            } else if let users = try? decoder.decode([User].self, from: data) {
                await MainActor.run {
                    self.users = users
                }
            } else {
                await MainActor.run {
                    self.tabErrors[.users] = "Users Decoding failed."
                }
            }
        } catch {
            print("DEBUG: [APP] Network error fetching users: \(error)")
            await MainActor.run {
                self.tabErrors[.users] = "Users Network Error: \(error.localizedDescription)"
            }
        }
    }

    func fetchDevlogs(for projectId: Int) async {
        guard let url = URL(string: "\(baseURL)/projects/\(projectId)/devlogs") else { return }
        print("DEBUG: [APP] Fetching devlogs for project \(projectId)")
        do {
            let request = createRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("DEBUG: [APP] Devlogs error (project \(projectId)): Status \(httpResponse.statusCode)")
                return
            }

            let decoder = JSONDecoder()
            // Try decoding as an object with "devlogs" key first
            if let devlogResponse = try? decoder.decode(DevlogResponse.self, from: data) {
                await MainActor.run {
                    self.devlogs[projectId] = devlogResponse.devlogs
                    print("DEBUG: [APP] Fetched \(devlogResponse.devlogs.count) devlogs for project \(projectId)")
                }
            } 
            // Then try decoding as a direct array
            else if let logs = try? decoder.decode([Devlog].self, from: data) {
                await MainActor.run {
                    self.devlogs[projectId] = logs
                    print("DEBUG: [APP] Fetched \(logs.count) devlogs for project \(projectId)")
                }
            }
        } catch {
            print("DEBUG: [APP] Error fetching devlogs for project \(projectId): \(error)")
        }
    }
    
    func startPolling() {
        print("Starting polling...")
        
        // Listen for manual refresh notifications from context menu
        NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshData"), object: nil, queue: .main) { _ in
            Task { await self.fetchData() }
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            print("Timer fired, fetching data...")
            Task {
                await self.fetchData()
            }
        }
        // Initial fetch
        Task {
            print("Initial fetch starting...")
            await self.fetchData()
            print("Initial fetch completed.")
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
