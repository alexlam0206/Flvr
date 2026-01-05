import Foundation
import SwiftUI

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

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let body: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }
}

@Observable
class FlavortownManager {
    var projects: [Project] = []
    var devlogs: [Int: [Devlog]] = [:]
    var storeItems: [StoreItem] = []
    var users: [User] = []
    
    var availableUpdate: GitHubRelease?
    var showUpdateAlert = false
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    init() {
        let savedIds = UserDefaults.standard.array(forKey: "flvr_target_item_ids") as? [Int] ?? []
        self.targetItemIds = Set(savedIds)
        
        Task {
            await checkForUpdates()
        }
    }
    
    func checkForUpdates() async {
        let lastCheck = UserDefaults.standard.double(forKey: "flvr_last_update_check")
        let now = Date().timeIntervalSince1970
        
        if now - lastCheck < 43200 && availableUpdate == nil {
            return
        }
        
        guard let url = URL(string: "https://api.github.com/repos/alexlam0206/Flvr/releases/latest") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            if release.tagName != appVersion {
                await MainActor.run {
                    self.availableUpdate = release
                    self.showUpdateAlert = true
                }
            }
            
            UserDefaults.standard.set(now, forKey: "flvr_last_update_check")
        } catch {
            print("DEBUG: [APP] Update check failed: \(error)")
        }
    }
    
    func remindMeLater() {
        showUpdateAlert = false
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "flvr_last_update_check")
    }
    
    var showDevlogInfo = false
    var isFetching = false
    var lastUpdated: Date?
    var tabErrors: [Tab: String] = [:]
    
    var targetItemIds: Set<Int> = [] {
        didSet {
            UserDefaults.standard.set(Array(targetItemIds), forKey: "flvr_target_item_ids")
        }
    }
    
    var cookiesPerHour: Int = UserDefaults.standard.integer(forKey: "flvr_cookies_per_hour") == 0 ? 10 : UserDefaults.standard.integer(forKey: "flvr_cookies_per_hour") {
        didSet {
            UserDefaults.standard.set(cookiesPerHour, forKey: "flvr_cookies_per_hour")
        }
    }
    
    func toggleTargetItem(_ id: Int) {
        if targetItemIds.contains(id) {
            targetItemIds.remove(id)
        } else {
            targetItemIds.insert(id)
        }
    }
    
    var totalTargetCost: Int {
        return storeItems
            .filter { targetItemIds.contains($0.id.value) }
            .compactMap { $0.ticketCost?.baseCost?.value }
            .reduce(0, +)
    }
    
    var remainingCookiesNeeded: Int {
        let currentCookies = currentUser?.cookies ?? 0
        return max(0, totalTargetCost - currentCookies)
    }
    
    var estimatedHoursToTarget: Double? {
        guard cookiesPerHour > 0, remainingCookiesNeeded > 0 else { return nil }
        return Double(remainingCookiesNeeded) / Double(cookiesPerHour)
    }
    
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
    
    var sortedStoreItems: [StoreItem] {
        return storeItems
            .filter { ($0.ticketCost?.baseCost?.value ?? 0) > 0 }
            .sorted { 
                ($0.ticketCost?.baseCost?.value ?? 0) < ($1.ticketCost?.baseCost?.value ?? 0)
            }
    }
    
    var sortedProjects: [Project] {
        return projects.sorted { ($0.title ?? "") < ($1.title ?? "") }
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
        case projects, store, settings
    }
    var selectedTab: Tab = .projects
    
    private let baseURL = "https://flavortown.hackclub.com/api/v1"
    private var timer: Timer?

    private func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15.0)
        request.addValue("true", forHTTPHeaderField: "X-Flavortown-Ext-2532")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            if !key.lowercased().hasPrefix("bearer ") {
                request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            } else {
                request.addValue(key, forHTTPHeaderField: "Authorization")
            }
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
                group.addTask { 
                    await self.fetchSpecificUser(id: id)
                    if let user = self.currentUser, let projectIds = user.projectIds {
                        await withTaskGroup(of: Void.self) { projectGroup in
                            for pid in projectIds {
                                projectGroup.addTask { await self.fetchSpecificProject(id: pid.value) }
                            }
                        }
                    }
                }
            } else {
                group.addTask { await self.fetchProjects() }
            }
        }
        
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
        do {
            let request = createRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "No error body"
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
            await MainActor.run {
                self.tabErrors[.projects] = "Network Error: \(error.localizedDescription)"
            }
        }
    }

    private func fetchDevlogsForProjects(_ projects: [Project]) async {
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

    func fetchDevlogs(for projectId: Int) async {
        guard let url = URL(string: "\(baseURL)/projects/\(projectId)/devlogs") else { return }
        do {
            let request = createRequest(url: url)
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            if let response = try? decoder.decode(DevlogResponse.self, from: data) {
                await MainActor.run {
                    self.devlogs[projectId] = response.devlogs
                }
            } else if let logs = try? decoder.decode([Devlog].self, from: data) {
                await MainActor.run {
                    self.devlogs[projectId] = logs
                }
            }
        } catch {}
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { await self.fetchData() }
        }
        Task { await fetchData() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
