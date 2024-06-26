//
//  SheetViews.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI
import StoreKit

struct SettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State var selectedFormat: FormatType
    @State var selectedLength: LengthType
    @State var selectedTone: ToneType
    
    var body: some View {
        NavigationStack{
            Form {
                Section(header: Text("Length")) {
                    Picker("Select Length", selection: $selectedLength) {
                        ForEach(LengthType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Format")) {
                    Picker("Select Format", selection: $selectedFormat) {
                        ForEach(FormatType.allCases, id: \.self) { option in
                            if option.rawValue == "bullet" {
                                Text("bullet point")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Tone")) {
                    Picker("Select Tone", selection: $selectedTone) {
                        ForEach(ToneType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
            }
            .navigationBarTitle("Summary Style")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let savedOutputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                            let outputSettings = OutputSettings(length: selectedLength, format: selectedFormat, tone: selectedTone, name: savedOutputSettings.name, prompt: savedOutputSettings.prompt)
                            UserDefaults.standard.storeOutputSettings(outputSettings, forKey: "Output Settings")
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }

    }
}

struct MoveSheet: View {
    var recording: Recording
    let currFolder: String
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var recordingsModel: RecordingsModel
    @State private var allFolders: [String] = []

    var body: some View {
        NavigationStack{
            Form {
                Section(header: Text("Selected Recording")) {
                    Text(recording.title)
                }
                
                Section(header: Text("Folders")) {
                    ForEach(allFolders, id: \.self) { folder in
                        MoveFolderPreview(folder)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                moveItem(folder)
                                presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .navigationBarTitle("Select Folder", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear(perform: {
            let allFolderURLs = Util.allFolderURLs()
            for url in allFolderURLs {
                if url.lastPathComponent != recording.folderPath && url.lastPathComponent != currFolder {
                    allFolders.append(url.lastPathComponent)
                }
            }
        })
    }
    
    private func ensureDirectoryExists(at url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func moveItem(_ folder: String) {
        let oldFolder = recording.folderPath
        
        let fileManager = FileManager.default
        let encoder = Util.encoder()
        let folderURL = Util.buildFolderURL(recording.folderPath)
        let rawFolderURL = folderURL.appendingPathComponent("raw")
        let oldAudioURL = rawFolderURL.appendingPathComponent(recording.audioPath)
        let oldFileURL = folderURL.appendingPathComponent(recording.filePath)
        let newFolderURL = Util.buildFolderURL(folder)
        let newRawFolderURL = newFolderURL.appendingPathComponent("raw")
        let newFileURL = newFolderURL.appendingPathComponent(recording.filePath)
        let newAudioURL = newRawFolderURL.appendingPathComponent(recording.audioPath)
        do {
            recording.folderPath = folder
            let data = try encoder.encode(recording)
            try data.write(to: newFileURL)
            try fileManager.removeItem(at: oldFileURL)
        } catch {
            print("can't move file \(error)")
        }
        do {
            try ensureDirectoryExists(at: newRawFolderURL)
            try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("can't move audio \(error)")
        }
        
        recordingsModel[oldFolder].recordings.removeAll(where: {$0.id == recording.id})
        recordingsModel[folder].recordings.insert(recording, at: 0)
    }
}

enum TransformType: String, Encodable, Decodable, CaseIterable {
    case actions
    case ideas
    case journal
}

struct TransformSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    @State var selectedTransform: TransformType = .actions
    @State var selectedFormat: FormatType = .bullet
    @State var selectedLength: LengthType = .short
    @State var selectedTone: ToneType = .casual
    let recording: Recording
    @EnvironmentObject var consumableModel: ConsumableModel
    @EnvironmentObject var storeModel: StoreModel

    var body: some View{
        NavigationStack {
            Form {
                Section(header: Text("Select Transformation")) {
                    CustomTransformPicker(index: $selectedTransform)
                }
                
                Section(header: Text("Length")) {
                    Picker("Select Length", selection: $selectedLength) {
                        ForEach(LengthType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Format")) {
                    Picker("Select Format", selection: $selectedFormat) {
                        ForEach(FormatType.allCases, id: \.self) { option in
                            if option.rawValue == "bullet" {
                                Text("bullet point")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Tone")) {
                    Picker("Select Tone", selection: $selectedTone) {
                        ForEach(ToneType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }//
            .navigationBarTitle("Transform Transcript")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        if !consumableModel.isOutputEmpty() || storeModel.subscriptions.count > 0 {
                            let currentOutputSettings = OutputSettings(length: selectedLength, format: selectedFormat, tone: selectedTone, name: selectedTransform.rawValue,  prompt: "", transformType: selectedTransform)
                            audioAPI.generateTransform(recording: recording, transformType: selectedTransform, outputSettings: currentOutputSettings)
                            consumableModel.useOutput()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct CustomTransformPicker: View {
    @Binding var index: TransformType

    let icons: [TransformType: String] = [
        .actions: "checklist",
        .ideas: "list.bullet",
        .journal: "book.closed"
    ]

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            ForEach(TransformType.allCases, id: \.self) { option in
                Button(action: {
                    self.index = option
                }) {
                    VStack {
                        Image(systemName: icons[option] ?? "")
                            .foregroundColor(self.index == option ? .black : .gray)
                            .padding(.horizontal, 35)
                        Text(option.rawValue)
                            .font(Font.system(size: 12))
                            .foregroundColor(self.index == option ? .black : .gray)
                    }
                    .padding(.vertical, 10)
                    .background((Color.white).opacity(self.index == option ? 1 : 0))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .id(option)
                .buttonStyle(BorderlessButtonStyle())
            }
            Spacer()
        }
        .padding(3)
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct UpgradeSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    let recording: Recording
    let context: UpgradeContext
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    @State private var isMonthlyPressed = false
    @State private var isAnnualPressed = false
    @EnvironmentObject var storeModel: StoreModel
    
    var body: some View {
        NavigationStack{
            Form {
            }
            .frame(height: 0)
            //.navigationBarTitle("GET UNLIMITED")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Upgrade")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 80)
                        .padding(.bottom, 10)
                }
            }
            VStack{
                Image(colorScheme == .dark ?  "highpastel" : "highpastel_black")
                    .scaleEffect(0.65)
                    .padding(.top, -35)
                    .padding(.bottom, -60)
                Text("Subscribe for UNLIMITED transcriptions and transformations")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
                Button(action: {
                    Task {
                        if let monthly = storeModel.monthlyProduct() {
                            isMonthlyPressed = true
                            await buy(product: monthly) {
                                isMonthlyPressed = false
                            }
                        }
                    }
                }) {
                    ZStack{
                        RoundedRectangle(cornerRadius: 55)
                            .fill(colorScheme == .dark ? .white : .black)
                            .scaleEffect(x: 0.68, y: 0.9)
                        if !isMonthlyPressed {
                             Text("UNLIMITED (monthly)\n$9.99/mo")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                                .scaleEffect(1, anchor: .center)
                                .padding(.trailing, 5)
                        }
                    }
                    .padding(.bottom, 10)
                }
                Button(action: {
                    Task {
                        if let annual = storeModel.annualProduct() {
                            isAnnualPressed = true
                            await buy(product: annual) {
                                isAnnualPressed = false
                            }
                        }
                    }
                }) {
                    ZStack{
                        RoundedRectangle(cornerRadius: 55)
                            .fill(colorScheme == .dark ? .white : .black)
                            .scaleEffect(x: 0.68, y: 0.9)
                        if !isAnnualPressed {
                         Text("UNLIMITED (annual)\n$99/yr")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                                .scaleEffect(1, anchor: .center)
                                .padding(.trailing, 5)
                        }
                    }
                    .padding(.bottom, 5)
                }
            // add Restore purchases
                Button("Restore Purchases") {
                    Task {
                        await storeModel.restorePurchases()
                    }
                }
                .padding(.bottom, 10)
            
            // add EULA & privacy policy
                PolicyView()
            }
        }
    }
    
    func buy(product: Product, completion: @escaping () -> Void) async {
        do {
            if try await storeModel.purchase(product) != nil {
                // regnerate all
                if context == .TranscriptUnlock {
                    recording.generateText = true
                    audioAPI.regenerateAll(recording: recording) {
                    }
                }
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            print("purchase failed")
        }
        completion()
    }
}

struct AccountSheet: View {
    @AppStorage("local_transcribe") var local_transcribe: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var consumableModel: ConsumableModel
    @EnvironmentObject var storeModel: StoreModel
    @State private var showUpgradeSheet = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("My Plan")) {
                    if storeModel.purchasedSubscriptions.count > 0 {
                        if storeModel.purchasedSubscriptions[0].id == "unlimited_monthly" {
                            Text("UNLIMITED (monthly)")
                        } else {
                            Text("UNLIMITED (annual)")
                        }
                    } else {
                        Text("Free Plan")
                    }
                    Button("Subscribe") {
                        showUpgradeSheet = true
                    }
                }
                Section(header: Text("Transcriptions Remaining")) {
                    if storeModel.purchasedSubscriptions.count > 0 {
                        Text("∞")
                    } else {
                        Text("\(consumableModel.remainingTranscript())")
                    }
                }
                Section(header: Text("Transformations Remaining")) {
                    if storeModel.purchasedSubscriptions.count > 0 {
                        Text("∞")
                    } else {
                        Text("\(consumableModel.remainingOutput())")

                    }
                }
                Section(header: Text("Privacy")) {
                    Toggle(isOn: $local_transcribe) {
                        Text("Local Transcription")
                    }
                }
                Section(header: Text("Version")) {
                    Text(version)
                        .foregroundColor(.gray)
                }
            }
            .navigationBarTitle("Account")
            .toolbar{
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showUpgradeSheet, onDismiss:{}){
            MiniUpgradeSheet()
                .environmentObject(storeModel)
        }
    }
    
    var version: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

}


struct MiniUpgradeSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var isMonthlyPressed = false
    @State private var isAnnualPressed = false
    @EnvironmentObject var storeModel: StoreModel
    
    var body: some View {
        NavigationStack{
            Form {
            }
            .frame(height: 0)
            //.navigationBarTitle("GET UNLIMITED")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Upgrade")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 80)
                        .padding(.bottom, 10)
                }
            }
            VStack{
                Image(colorScheme == .dark ?  "highpastel" : "highpastel_black")
                    .scaleEffect(0.65)
                    .padding(.top, -35)
                    .padding(.bottom, -60)
                Text("Subscribe for UNLIMITED transcriptions and transformations")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
                Button(action: {
                    Task {
                        if let monthly = storeModel.monthlyProduct() {
                            isMonthlyPressed = true
                            await buy(product: monthly) {
                                isMonthlyPressed = false
                            }
                        }
                    }
                }) {
                    ZStack{
                        RoundedRectangle(cornerRadius: 55)
                            .fill(colorScheme == .dark ? .white : .black)
                            .scaleEffect(x: 0.68, y: 0.9)
                        if !isMonthlyPressed {
                             Text("UNLIMITED (monthly)\n$9.99/mo")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                                .scaleEffect(1, anchor: .center)
                                .padding(.trailing, 5)
                        }
                    }
                    .padding(.bottom, 10)
                }
                Button(action: {
                    Task {
                        if let annual = storeModel.annualProduct() {
                            isAnnualPressed = true
                            await buy(product: annual) {
                                isAnnualPressed = false
                            }
                        }
                    }
                }) {
                    ZStack{
                        RoundedRectangle(cornerRadius: 55)
                            .fill(colorScheme == .dark ? .white : .black)
                            .scaleEffect(x: 0.68, y: 0.9)
                        if !isAnnualPressed {
                         Text("UNLIMITED (annual)\n$99/yr")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                                .scaleEffect(1, anchor: .center)
                                .padding(.trailing, 5)
                        }
                    }
                    .padding(.bottom, 5)
                }
            // add Restore purchases
                Button("Restore Purchases") {
                    Task {
                        await storeModel.restorePurchases()
                    }
                }
                .padding(.bottom, 10)
            
            // add EULA & privacy policy
                PolicyView()
            }
        }
    }
    
    func buy(product: Product, completion: @escaping () -> Void) async {
        do {
            if try await storeModel.purchase(product) != nil {
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            print("purchase failed")
        }
        completion()
    }
}

struct PolicyView: View {
    var body: some View {
        VStack {
            Text("Your subscriptions will auto-renew until canceled. You can manage your subscriptions in the Settings App.")
                .multilineTextAlignment(.center)
            HStack {
                Link("Terms of Service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("and")
                Link("Privacy Policy", destination: URL(string: "https://pythonlearner1025.github.io/Monolog.ai/")!)
            }
            .multilineTextAlignment(.center)
        }
        .font(.system(size: CGFloat(10)))
    }
}
