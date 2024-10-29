import SwiftUI
import SwiftData
import CryptoKit
import UniformTypeIdentifiers


struct CoreChatView: View {
    @State private var msgs: [Message] = [] // 메시지 리스트로 수정
    @State private var text: String = ""
    @State private var llm: LLM? = nil
    @State private var showFilePicker: Bool = false
    @State private var modelURL: URL? = nil
    @State private var tok: BPETokenizer? = nil
    @State private var isModelLoaded: Bool = false
    @State private var currentUserMessageId: UUID?
    @State private var isGenerating: Bool = false
    
    @State private var isSystemPt: Bool = false
    @State private var sysPrompt: String = """
        You are the best assistant ever. Answer questions thoughtfully and with emojis.
        """

    
    @State var showAddEventModal = false
    
    private var latestMessageId: UUID? {
        msgs.sorted(by: { $0.timestamp < $1.timestamp }).last?.id
    }
    
    var body: some View {
        ZStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack {
                            ZStack {
                                HStack {
                                    Text("Test Chat")
                                    Circle()
                                        .fill(isModelLoaded ? Color.green : Color.red)
                                        .frame(width: 10, height: 10)
                                        .padding(.leading, 5)
                                        .onTapGesture {
                                            clearMessages()
                                        }
                                }
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        isSystemPt.toggle()
                                    }) {
                                        Image(systemName: "gear")
                                    }
                                    .padding(.trailing, 25)
                                    .sheet(isPresented: $isSystemPt) {
                                        SystemEdit(title: "System Settings", edit: "Edit", bind_edit: $sysPrompt)
                                    }
                                }
                            }
                            ForEach(Array(msgs.sorted(by: { $0.timestamp < $1.timestamp }).enumerated()), id: \.element.id) { index, msg in
                                CoreChatBox(msg: msg, delete: {
                                    deleteItems(offsets: IndexSet(integer: index))
                                }).id(msg.id)
                            }
                        }
                        .onChange(of: msgs, initial: false) { _, _ in
                            if let latestID = latestMessageId {
                                withAnimation {
                                    proxy.scrollTo(latestID, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                HStack {
                    Button(action: {
                        showFilePicker.toggle()
                    }) {
                        Image(systemName: "plus")
                    }
                    .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.mlpackage, .mlmodelc], allowsMultipleSelection: false) { result in
                        handleFileImport(result: result)
                    }
                    .padding(.bottom, 10)
                    
                    TextField("Type a message", text: $text)
                        .padding(.bottom, 10)
                    
                    Button(action: {
                        if isGenerating {
                            isGenerating = false
                        } else {
                            print("Sending message...")
                            sendMessage()
                        }
                    }) {
                        Image(systemName: isGenerating ? "stop.fill": "paperplane" )
                    }
                    .padding(.bottom, 10)
                }
                .padding([.leading, .trailing], 25)
            }
        }
        .onChange(of: modelURL, initial: false) { _, _  in
            loadModel()
        }
        .onAppear {
            tok = loadTiktokenBPEFromBundle()
        }
        .sheet(isPresented: $showAddEventModal){
//            AddEvent()
        }
    }
    
    private func get_Gen() -> Bool {
        return isGenerating
    }
    
    private func clearMessages() {
        msgs.removeAll()
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            modelURL = urls.first
            print("Import Completed!")
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func sendMessage() {
        if text.isEmpty { return }
        let result = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n\(sysPrompt)<|eot_id|>" + "<|start_header_id|>user<|end_header_id|>\n\n\(text)<|eot_id|>" + "<|start_header_id|>assistant<|end_header_id|>\n\n"

        
        guard let tokenizer = tok else { return }
        let (a, t) = tokenizer.encode(result)
        print(a)
        print(t)
        let userMessage = Message(timestamp: Date(), mess: text, role: .user)
        msgs.append(userMessage)
        
        let modelMessage = Message(timestamp: Date(), mess: "...", role: .model)
        msgs.append(modelMessage)
        currentUserMessageId = modelMessage.id
        text = ""
        
        Task {
            guard let llm = llm else { return }
            isGenerating = true
            var responseText = ""
            _ = await llm.openLoop(tokens: t, open_func: { int_array in
                let output = tokenizer.decode(int_array).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 배열에서 인덱스를 찾아 직접 메시지를 수정
                if let index = msgs.firstIndex(where: { $0.id == currentUserMessageId }), output.count > 0 && responseText.count < output.count {
                    responseText = output
                    msgs[index].mess = output
                }
                return get_Gen()
            })
            isGenerating = false
        }
    }
    
    private func loadModel() {
        Task {
            if let uri = modelURL, let lm = await loadLLM(modelURL: uri) {
                self.llm = lm
                isModelLoaded = true
            } else {
                isModelLoaded = false
            }
        }
    }
    
    private func loadLLM(modelURL: URL) async -> LLM? {
        do {
            let mlmodel = try await ModelLoader.load(url: modelURL)
            return LLM(model: mlmodel)
        } catch {
            print("Error loading model: \(error)")
        }
        return nil
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            msgs.remove(at: index)
        }
    }
    
    func loadTiktokenBPEFromBundle() -> BPETokenizer? {
        let numReservedSpecialTokens = 256
        if let tokenizerModelPath = Bundle.main.path(forResource: "tokenizer", ofType: "model") {
            do {
                let data = try readFileCached(tokenizerModelPath)
                let mergeableRanks = loadTiktokenBPE(contents: data)
                let specialTokens = [
                    "<|begin_of_text|>",
                    "<|end_of_text|>",
                    "<|reserved_special_token_0|>",
                    "<|reserved_special_token_1|>",
                    "<|reserved_special_token_2|>",
                    "<|reserved_special_token_3|>",
                    "<|start_header_id|>",
                    "<|end_header_id|>",
                    "<|reserved_special_token_4|>",
                    "<|eot_id|>",
                ] + (5..<numReservedSpecialTokens - 5).map { "<|reserved_special_token_\($0)|>" }
                
                let specialTokensDict = createSpecialTokensDictionary(mergeableRanks: mergeableRanks, specialTokens: specialTokens)
                return BPETokenizer(mergeableRanks: mergeableRanks, specialTokens: specialTokensDict)
            } catch {
                print("Error loading tokenizer model: \(error)")
            }
        }
        return nil
    }
    
    func createSpecialTokensDictionary(mergeableRanks: [Data: Int], specialTokens: [String]) -> [String: Int] {
        var specialTokensDict: [String: Int] = [:]
        for (i, token) in specialTokens.enumerated() {
            specialTokensDict[token] = mergeableRanks.count + i
        }
        return specialTokensDict
    }
    
    func readFileCached(_ blobpath: String) throws -> Data {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("data-gym-cache")
        let cacheKey = SHA256.hash(data: Data(blobpath.utf8)).compactMap { String(format: "%02hhx", $0) }.joined()
        let cachePath = cacheDir.appendingPathComponent(cacheKey)
        
        if FileManager.default.fileExists(atPath: cachePath.path) {
            return try Data(contentsOf: cachePath)
        }
        
        let contents = try readFile(blobpath: blobpath)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        try contents.write(to: cachePath)
        return contents
    }
    
    func readFile(blobpath: String) throws -> Data {
        guard let filePath = Bundle.main.path(forResource: "tokenizer", ofType: "model") else {
            throw NSError(domain: "FileNotFoundError", code: 1, userInfo: nil)
        }
        return try Data(contentsOf: URL(fileURLWithPath: filePath))
    }
    
    func loadTiktokenBPE(contents: Data) -> [Data: Int] {
        var mergeableRanks = [Data: Int]()
        let fileContents = String(data: contents, encoding: .utf8) ?? ""
        for line in fileContents.split(separator: "\n") {
            let parts = line.split(separator: " ")
            if parts.count == 2, let tokenData = Data(base64Encoded: String(parts[0])), let rank = Int(parts[1]) {
                mergeableRanks[tokenData] = rank
            }
        }
        return mergeableRanks
    }
}




private extension UTType {
    static let mlpackage = UTType(filenameExtension: "mlpackage", conformingTo: .item)!
    static let mlmodelc = UTType(filenameExtension: "mlmodelc", conformingTo: .item)!
}

#Preview {
    CoreChatView()
}
