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
        case .settings: return "Settings"
        }
    }

    private var mainContent: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                
                Picker("", selection: $manager.selectedTab) {
                    Label("Projects", systemImage: "hammer.fill").tag(FlavortownManager.Tab.projects)
                    Label("Store", systemImage: "cart.fill").tag(FlavortownManager.Tab.store)
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
            
            if let project = manager.viewingProject {
                ProjectDetailView(project: project, manager: manager)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .task {
            manager.startPolling()
        }
        .alert("New Update Available", isPresented: $manager.showUpdateAlert, presenting: manager.availableUpdate) { release in
            Button("Update Now") {
                if let url = URL(string: release.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
                manager.showUpdateAlert = false
            }
            Button("Remind Me Later") {
                manager.remindMeLater()
            }
            Button("Cancel", role: .cancel) {
                manager.showUpdateAlert = false
            }
        } message: { release in
            Text("A new version (\(release.tagName)) is available. Would you like to update?\n\n\(release.body ?? "")")
        }
    }

    @ViewBuilder
    private var content: some View {
        if manager.selectedTab == .settings {
            SettingsView(manager: manager)
        } else if manager.isFetching && manager.projects.isEmpty && manager.storeItems.isEmpty {
            loadingView
        } else if let error = manager.tabErrors[manager.selectedTab] {
            errorView(error)
        } else if !manager.isFetching && manager.projects.isEmpty && manager.storeItems.isEmpty {
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
                ForEach(manager.sortedStoreItems) { item in
                    StoreItemRow(item: item, manager: manager)
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
                    ForEach(manager.sortedStoreItems) { item in
                        StoreCard(item: item, manager: manager)
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
                            Text("\(cookies) 🍪")
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
    let manager: FlavortownManager
    
    var isTargeted: Bool {
        manager.targetItemIds.contains(item.id.value)
    }
    
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
            
            HStack {
                if let cost = item.ticketCost?.baseCost {
                    Text("\(cost.value) COOKIES")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button {
                    manager.toggleTargetItem(item.id.value)
                } label: {
                    Image(systemName: isTargeted ? "target" : "circle")
                        .foregroundStyle(isTargeted ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 240)
        .background(isTargeted ? Color.orange.opacity(0.05) : Color.primary.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 2)
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
        Button {
            manager.viewingProject = project
        } label: {
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
                        .buttonStyle(.plain)
                        .help("Open Repository")
                    }
                }
                
                if let desc = project.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if manager.showDevlogInfo, let devlogIds = project.devlogIds, !devlogIds.isEmpty {
                        Text("\(devlogIds.count) logs")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .cornerRadius(4)
                    }
                    
                    if let createdAt = project.createdAt {
                        Text(createdAt)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ProjectDetailView: View {
    let project: Project
    let manager: FlavortownManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project Detail")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(project.title ?? "Untitled")
                        .font(.headline)
                }
                Spacer()
                Button { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        manager.viewingProject = nil 
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let desc = project.description {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "DESCRIPTION")
                            Text(desc)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "LINKS")
                        
                        FlowLayout(spacing: 8) {
                            if let repo = project.repoUrl, let url = URL(string: repo) {
                                LinkButton(title: "Repository", systemImage: "link", url: url)
                            }
                            
                            if let demo = project.demoUrl, let url = URL(string: demo) {
                                LinkButton(title: "Demo", systemImage: "play.circle", url: url, color: .blue)
                            }
                        }
                    }
                    
                    if let devlogIds = project.devlogIds, !devlogIds.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "DEVLOGS (\(devlogIds.count))")
                                Spacer()
                                if manager.devlogs[project.id.value] == nil {
                                    Button("Load All") {
                                        Task { await manager.fetchDevlogs(for: project.id.value) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            if let logs = manager.devlogs[project.id.value] {
                                VStack(spacing: 0) {
                                    ForEach(logs) { log in
                                        DevlogRow(log: log)
                                        if log.id != logs.last?.id {
                                            Divider().padding(.leading, 32)
                                        }
                                    }
                                }
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(12)
                            } else {
                                ContentUnavailableView("Devlogs Not Loaded", systemImage: "clock.arrow.2.circlepath", description: Text("Click Load All to fetch project history"))
                                    .controlSize(.small)
                                    .padding(.vertical)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(.secondary)
            .kerning(1)
    }
}

struct LinkButton: View {
    let title: String
    let systemImage: String
    let url: URL
    var color: Color = .primary
    
    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .foregroundStyle(color)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct DevlogRow: View {
    let log: Devlog
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange.opacity(0.6))
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.body ?? "No content")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 8) {
                    if let duration = log.durationSeconds {
                        Label("\(duration / 60)m", systemImage: "timer")
                    }
                    if let date = log.createdAt {
                        Text("• \(date)")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

struct FlowLayout: View {
    let spacing: CGFloat
    let views: [AnyView]
    
    init<Views>(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Views) where Views: View {
        self.spacing = spacing
        self.views = [AnyView(content())]
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<views.count, id: \.self) { index in
                views[index]
            }
        }
    }
}

struct StoreItemRow: View {
    let item: StoreItem
    let manager: FlavortownManager
    
    var isTargeted: Bool {
        manager.targetItemIds.contains(item.id.value)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url)
                    .frame(width: 44, height: 44)
                    .clipped()
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "cart").foregroundStyle(.secondary))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Unknown Item")
                    .font(.subheadline).bold()
                
                HStack {
                    if let cost = item.ticketCost?.baseCost {
                        Text("\(cost.value) 🍪")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    
                    if let stock = item.stock {
                        Text("• \(stock.value) in stock")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                manager.toggleTargetItem(item.id.value)
            } label: {
                Image(systemName: isTargeted ? "target" : "circle")
                    .foregroundStyle(isTargeted ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView: View {
    @Bindable var manager: FlavortownManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("USER CONFIGURATION")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("API Key", systemImage: "key.fill")
                                    .font(.caption.bold())
                                SecureField("Bearer token...", text: $manager.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label("User ID", systemImage: "person.fill")
                                    .font(.caption.bold())
                                TextField("Your ID...", text: $manager.userId)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TARGET TRACKING")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Label("Cookies per hour", systemImage: "timer")
                                Spacer()
                                TextField("", value: $manager.cookiesPerHour, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total Target Cost")
                                Spacer()
                                Text("\(manager.totalTargetCost) 🍪")
                                    .bold()
                            }
                            
                            HStack {
                                Text("Remaining Needed")
                                Spacer()
                                Text("\(manager.remainingCookiesNeeded) 🍪")
                                    .foregroundStyle(.orange)
                                    .bold()
                            }
                            
                            if let hours = manager.estimatedHoursToTarget {
                                HStack {
                                    Text("Estimated Time")
                                    Spacer()
                                    Text(String(format: "%.1f hours", hours))
                                        .bold()
                                }
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DISPLAY OPTIONS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.secondary)
                        
                        Toggle(isOn: $manager.showDevlogInfo) {
                            Label("Show Devlog Counts", systemImage: "clock.badge.checkmark")
                        }
                        .toggleStyle(.switch)
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Flvr v\(manager.appVersion)")
                        .font(.system(size: 10, weight: .bold))
                    Text("Made with 🔥 by Hack Club")
                        .font(.system(size: 9))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
                .padding(.top)
            }
            .padding()
        }
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
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView().controlSize(.small)
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                Image(systemName: "photo").foregroundStyle(.secondary)
            @unknown default:
                EmptyView()
            }
        }
    }
}
