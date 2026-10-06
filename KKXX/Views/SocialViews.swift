import SwiftUI

// MARK: - 好友列表
struct FriendsListView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var friends: [[String: Any]] = []
    @State private var requests: [[String: Any]] = []
    @State private var loading = true
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                if !requests.isEmpty {
                    Section("好友申请（\(requests.count)）") {
                        ForEach(requests.indices, id: \.self) { i in
                            let r = requests[i]
                            HStack {
                                avatarCircle(base64: (r["avatar"] as? String) ?? "", size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text((r["nickname"] as? String)?.isEmpty == false ? (r["nickname"] as! String) : (r["kx_number"] as! String))
                                        .font(.subheadline.weight(.medium))
                                    Text((r["message"] as? String)?.isEmpty == false ? (r["message"] as! String) : "请求添加你为好友")
                                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button("同意") { acceptRequest(i) }
                                    .buttonStyle(.borderedProminent).controlSize(.small)
                                Button("拒绝") { rejectRequest(i) }
                                    .buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AddFriendView()
                    } label: {
                        Label("添加好友", systemImage: "person.badge.plus")
                    }
                }

                Section("好友") {
                    if friends.isEmpty && !loading {
                        Text("还没有好友，快去通过 KX 号添加吧")
                            .foregroundColor(.secondary)
                    }
                    ForEach(friends.indices, id: \.self) { i in
                        let f = friends[i]
                        Button {
                            navPath.append("chat:" + (f["kx_number"] as? String ?? ""))
                        } label: {
                            HStack {
                                avatarCircle(base64: (f["avatar"] as? String) ?? "", size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text((f["nickname"] as? String)?.isEmpty == false ? (f["nickname"] as! String) : (f["kx_number"] as! String))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("KX:\(f["kx_number"] as? String ?? "")")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if (f["unread"] as? Int ?? 0) > 0 {
                                    Text("\(f["unread"] as! Int)")
                                        .font(.caption2).bold()
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color.red).clipShape(Circle())
                                }
                            }
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) { deleteFriend(i) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("好友")
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .navigationDestination(for: String.self) { route in
                if route.hasPrefix("chat:") {
                    ChatView(kx: String(route.dropFirst(5)), friendNick: friendName(kx: String(route.dropFirst(5))))
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func friendName(kx: String) -> String {
        friends.first(where: { ($0["kx_number"] as? String) == kx }).flatMap {
            (($0["nickname"] as? String)?.isEmpty == false) ? $0["nickname"] as? String : kx
        } ?? kx
    }

    private func reload() async {
        do {
            async let f = SyncService().friendList(settings: settings)
            async let r = SyncService().listRequests(settings: settings)
            friends = try await f
            requests = try await r
        } catch { }
        loading = false
    }

    private func acceptRequest(_ i: Int) {
        guard let id = requests[i]["id"] as? Int else { return }
        Task {
            _ = try? await SyncService().respondRequest(id: id, accept: true, settings: settings)
            await reload()
        }
    }
    private func rejectRequest(_ i: Int) {
        guard let id = requests[i]["id"] as? Int else { return }
        Task {
            _ = try? await SyncService().respondRequest(id: id, accept: false, settings: settings)
            await reload()
        }
    }

    private func deleteFriend(_ i: Int) {
        guard let kx = friends[i]["kx_number"] as? String else { return }
        Task {
            _ = try? await SyncService().deleteFriend(kx: kx, settings: settings)
            await reload()
        }
    }
}

// MARK: - 添加好友
struct AddFriendView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var kx = ""
    @State private var result: [String: Any]?
    @State private var message = ""
    @State private var searching = false
    @State private var tip = ""

    var body: some View {
        List {
            Section {
                Text("输入对方 KX 号，精准查找并添加好友")
                    .font(.footnote).foregroundColor(.secondary)
                TextField("请输入 KX 号", text: $kx)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .onSubmit { search() }
                Button { search() } label: {
                    HStack { Spacer(); Text("搜索").bold(); Spacer() }
                }
                .disabled(kx.isEmpty || searching)
            }

            if let r = result {
                Section("搜索结果") {
                    HStack(spacing: 12) {
                        avatarCircle(base64: (r["avatar"] as? String) ?? "", size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text((r["nickname"] as? String)?.isEmpty == false ? (r["nickname"] as! String) : "KK 用户")
                                .font(.headline)
                            Text("KX:\(r["kx"] as? String ?? "")").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    if (r["is_friend"] as? Bool) == true {
                        Text("你们已经是好友").foregroundColor(.secondary)
                    } else {
                        TextField("请输入验证信息（选填）", text: $message)
                        Button { sendRequest() } label: {
                            HStack { Spacer(); Text("添加好友"); Spacer() }
                        }.buttonStyle(.borderedProminent)
                    }
                }
            }

            if !tip.isEmpty {
                Section { Text(tip).foregroundColor(.secondary).font(.footnote) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("添加好友")
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    private func search() {
        searching = true; tip = ""
        Task {
            do {
                result = try await SyncService().searchKx(kx.trimmingCharacters(in: .whitespaces), settings: settings)
            } catch {
                tip = "未找到对应 KX 号的用户，请检查后重新输入"
                result = nil
            }
            searching = false
        }
    }

    private func sendRequest() {
        guard let r = result, let toKx = r["kx"] as? String else { return }
        Task {
            do {
                tip = try await SyncService().sendRequest(toKx: toKx, message: message, settings: settings)
                message = ""
            } catch {
                tip = (error as NSError).localizedDescription
            }
        }
    }
}

// MARK: - 聊天窗口
struct ChatView: View {
    let kx: String
    let friendNick: String
    @EnvironmentObject var settings: AppSettings
    @State private var messages: [[String: Any]] = []
    @State private var text = ""
    @State private var lastTs: Int64 = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(messages.indices, id: \.self) { i in
                            bubble(messages[i])
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last, let id = last["id"] as? Int {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }
            HStack(spacing: 10) {
                TextField("发消息…", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
                }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .padding(.bottom, 90)
        .navigationTitle("\(friendNick)（KX:\(kx)）")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings.tabBarHidden = true
            startPoll()
        }
        .onDisappear {
            settings.tabBarHidden = false
            timer?.invalidate()
        }
    }

    private func bubble(_ m: [String: Any]) -> some View {
        let mine = (m["mine"] as? Int) == 1
        return HStack {
            if mine { Spacer() }
            Text(m["text"] as? String ?? "")
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(mine ? Color(red: 0.0, green: 0.76, blue: 0.38) : Color(uiColor: .secondarySystemBackground))
                .foregroundColor(mine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if !mine { Spacer() }
        }
    }

    private func startPoll() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { await pull() }
        }
        Task { await pull() }
    }

    private func pull() async {
        do {
            let list = try await SyncService().pullMessages(withKx: kx, afterTs: lastTs, settings: settings)
            if !list.isEmpty {
                messages.append(contentsOf: list)
                if let last = list.last, let ts = last["created_at"] as? Int64 { lastTs = ts }
            }
        } catch { }
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        text = ""
        Task {
            do {
                try await SyncService().sendMessage(toKx: kx, text: t, settings: settings)
                await pull()
            } catch { }
        }
    }
}

// MARK: - 头像小工具
@ViewBuilder
func avatarCircle(base64: String, size: CGFloat) -> some View {
    Group {
        if let d = Data(base64Encoded: base64), let img = UIImage(data: d) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: size))
                .foregroundColor(.secondary)
        }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
}
