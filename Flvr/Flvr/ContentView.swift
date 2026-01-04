//
//  ContentView.swift
//  Flvr
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Bindable var manager: FlavortownManager
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        #if os(macOS)
        mainContent
            .frame(width: 380, height: 500)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        #else
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .task {
            manager.startPolling()
        }
        #endif
    }

    private var sidebar: some View {
        List(selection: $manager.selectedTab) {
            Section("Flavortown") {
                Label("Projects", systemImage: "hammer.fill").tag(FlavortownManager.Tab.projects)
                Label("Store", systemImage: "cart.fill").tag(FlavortownManager.Tab.store)
                Label("Users", systemImage: "person.2.fill").tag(FlavortownManager.Tab.users)
            }
            
            Section("App") {
                Label("Settings", systemImage: "gearshape.fill").tag(FlavortownManager.Tab.settings)
            }
        }
        .navigationTitle("Flvr")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailContent: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            content
            
            footer
        }
        .navigationTitle(tabTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if manager.isFetching {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await manager.fetchData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var tabTitle: String {
        switch manager.selectedTab {
        case .projects: return "Projects"
        case .store: return "Store"
        case .users: return "Users"
        case .settings: return "Settings"
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            
            Picker("", selection: $manager.selectedTab) {
                Label("Projects", systemImage: "hammer.fill").tag(FlavortownManager.Tab.projects)
                Label("Store", systemImage: "cart.fill").tag(FlavortownManager.Tab.store)
                Label("Users", systemImage: "person.2.fill").tag(FlavortownManager.Tab.users)
                Label("Settings", systemImage: "gearshape.fill").tag(FlavortownManager.Tab.settings)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .controlSize(.small)
            
            Divider()
            
            content
            
            footer
        }
        .contentShape(Rectangle())
        .task {
            manager.startPolling()
        }
    }

    @ViewBuilder
    private var content: some View {
        if manager.selectedTab == .settings {
            SettingsView(manager: manager)
        } else if manager.isFetching && manager.projects.isEmpty && manager.storeItems.isEmpty && manager.users.isEmpty {
            loadingView
        } else if let error = manager.tabErrors[manager.selectedTab] {
            errorView(error)
        } else if !manager.isFetching && manager.projects.isEmpty && manager.storeItems.isEmpty && manager.users.isEmpty {
            emptyView
        } else {
            adaptiveList
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.largeTitle).foregroundStyle(.red)
            Text("API Fetch Error").font(.headline)
            ScrollView {
                Text(error)
                    .font(.caption).monospaced()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 150)
            
            Button("Try Again") { Task { await manager.fetchData() } }
                .buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Fetching data from Flavortown...")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("No data found").font(.headline)
            Text("Try refreshing or check your API key in Settings.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            
            if manager.apiKey.isEmpty {
                Text("⚠️ API Key is missing")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
            
            Button("Refresh Now") { Task { await manager.fetchData() } }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var adaptiveList: some View {
        #if os(iOS)
        if sizeClass == .regular {
            gridView
        } else {
            listView
        }
        #else
        listView
        #endif
    }

    private var listView: some View {
        List {
            switch manager.selectedTab {
            case .projects:
                ForEach(manager.sortedProjects) { project in
                    ProjectRow(project: project, manager: manager)
                }
            case .store:
                ForEach(manager.storeItems) { item in
                    StoreItemRow(item: item)
                }
            case .users:
                ForEach(manager.sortedUsers) { user in
                    UserRow(user: user, isMe: String(user.id.value) == manager.userId)
                }
            case .settings:
                EmptyView()
            }
        }
        .listStyle(.plain)
    }

    private var gridView: some View {
        ScrollView {
            let columns = [GridItem(.adaptive(minimum: 300), spacing: 20)]
            LazyVGrid(columns: columns, spacing: 20) {
                switch manager.selectedTab {
                case .projects:
                    ForEach(manager.sortedProjects) { project in
                        ProjectCard(project: project, manager: manager)
                    }
                case .store:
                    ForEach(manager.storeItems) { item in
                        StoreCard(item: item)
                    }
                case .users:
                    ForEach(manager.sortedUsers) { user in
                        UserCard(user: user, isMe: String(user.id.value) == manager.userId)
                    }
                case .settings:
                    EmptyView()
                }
            }
            .padding()
        }
    }
    
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Flvr")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    if let time = manager.totalLoggedTimeText {
                        Text(time)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if manager.apiKey.isEmpty {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .help("API Key missing! Set it in Settings.")
                    }
                }
                
                if let user = manager.currentUser {
                    HStack(spacing: 6) {
                        Text(user.displayName ?? "Anonymous")
                        if let cookies = user.cookies {
                            Text("🍪 \(cookies)")
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                } else if !manager.userId.isEmpty {
                    Text("User ID: \(manager.userId)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                if let selectedId = manager.selectedProjectId,
                   let project = manager.userProjects.first(where: { $0.id.value == selectedId }) {
                    Text(project.title ?? "Untitled project")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
    
    private var footer: some View {
        HStack {
            if let last = manager.lastUpdated {
                Text("Last updated: \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if manager.isFetching {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
            } else {
                Button {
                    Task { await manager.fetchData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Refresh Data")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }
}

struct ProjectCard: View {
    let project: Project
    let manager: FlavortownManager
    
    var isMine: Bool {
        guard let user = manager.currentUser, let projectIds = user.projectIds else { return false }
        return projectIds.contains { $0.value == project.id.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(project.title ?? "Untitled")
                    .font(.headline)
                
                if isMine {
                    Text("MY PROJECT")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                if let url = project.repoUrl, let _ = URL(string: url) {
                    Link(destination: URL(string: url)!) {
                        Image(systemName: "link.circle.fill")
                            .font(.title3)
                    }
                }
            }
            
            Text(project.description ?? "No description provided.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            if manager.showDevlogInfo, let devlogIds = project.devlogIds, !devlogIds.isEmpty {
                HStack {
                    Image(systemName: "clock.fill")
                    Text("\(devlogIds.count) devlogs")
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 180)
        .background(isMine ? Color.orange.opacity(0.05) : Color.primary.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMine ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct StoreCard: View {
    let item: StoreItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url)
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            }
            
            Text(item.name ?? "Unknown Item")
                .font(.headline)
            
            if let cost = item.ticketCost?.baseCost {
                Text("\(cost.value) TICKETS")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 240)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct UserCard: View {
    let user: User
    let isMe: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            if let avatar = user.avatar, let url = URL(string: avatar) {
                CachedAsyncImage(url: url)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(Text(user.displayName?.prefix(1) ?? "?").font(.title2))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.displayName ?? "Anonymous")
                        .font(.headline)
                    if isMe {
                        Text("ME")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .cornerRadius(4)
                    }
                }
                
                if let cookies = user.cookies {
                    Text("\(cookies) 🍪")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(isMe ? Color.orange.opacity(0.05) : Color.primary.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMe ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct ProjectRow: View {
    let project: Project
    let manager: FlavortownManager
    
    var isMine: Bool {
        guard let user = manager.currentUser, let projectIds = user.projectIds else { return false }
        return projectIds.contains { $0.value == project.id.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(isMine ? .orange : .primary)
                
                if isMine {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                if let url = project.repoUrl, let _ = URL(string: url) {
                    Link(destination: URL(string: url)!) {
                        Image(systemName: "arrow.up.right.circle.fill")
                    }
                }
            }
            
            if let desc = project.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            if manager.showDevlogInfo, let devlogIds = project.devlogIds, !devlogIds.isEmpty {
                Text("\(devlogIds.count) logs logged")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    
}
}

struct StoreItemRow: View {
    let item: StoreItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unknown Item")
                    .font(.headline)
                if let stock = item.stock?.value {
                    Text("\(stock) in stock")
                        .font(.caption)
                        .foregroundStyle(stock > 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                }
            }
            
            Spacer()
            
            if let cost = item.ticketCost?.baseCost {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(cost.value)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("TICKETS")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UserRow: View {
    let user: User
    let isMe: Bool
    
    var body: some View {
        HStack {
            if let avatar = user.avatar, let url = URL(string: avatar) {
                CachedAsyncImage(url: url)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.displayName ?? "Anonymous")
                        .font(.subheadline).bold()
                        .foregroundStyle(isMe ? .orange : .primary)
                    
                    if isMe {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
                
                if let cookies = user.cookies {
                    Text("\(cookies) cookies 🍪")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let projects = user.projectIds?.count {
                Text("\(projects) projects")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isMe ? Color.orange.opacity(0.1) : Color.primary.opacity(0.05))
                    .foregroundStyle(isMe ? .orange : .primary)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView: View {
    @Bindable var manager: FlavortownManager
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("API CONFIGURATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    SecureField("Flavortown API Key", text: $manager.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("Get your key from the Flavortown dashboard. It should start with 'ft_sk_'.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("MY PROFILE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    TextField("User ID", text: $manager.userId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    
                    if let user = manager.currentUser {
                        HStack {
                            if let avatar = user.avatar, let url = URL(string: avatar) {
                                CachedAsyncImage(url: url)
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())
                            }
                            Text(user.displayName ?? "Anonymous")
                                .font(.headline)
                        }
                    } else if !manager.userId.isEmpty {
                        Text("User not found. Try refreshing.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("MY PROJECT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    if manager.userProjects.isEmpty {
                        Text("No projects found for this user.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Your Project", selection: $manager.selectedProjectId) {
                            Text("None").tag(Optional<Int>.none)
                            ForEach(manager.userProjects) { project in
                                Text(project.title ?? "Untitled").tag(Optional(project.id.value))
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if let selectedId = manager.selectedProjectId,
                           let project = manager.userProjects.first(where: { $0.id.value == selectedId }) {
                            if let time = manager.totalLoggedTimeText {
                                Text("Total time: \(time)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Toggle("Show devlog info in project list", isOn: $manager.showDevlogInfo)
                    .controlSize(.small)
            }
            
            Section {
                Button("Verify & Refresh") {
                    Task { await manager.fetchData() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About Flvr")
                        .font(.headline)
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            }
        }
        .formStyle(.grouped)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct CachedAsyncImage: View {
    let url: URL
    
    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .default)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure(_):
                Color.gray.opacity(0.1)
            case .empty:
                ProgressView().controlSize(.small)
            @unknown default:
                EmptyView()
            }
        }
    }
}

#Preview {
    ContentView(manager: FlavortownManager())
}
