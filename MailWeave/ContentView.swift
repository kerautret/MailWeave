import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct Recipient: Identifiable, Codable {
    var id = UUID()
    var name: String
    var email: String
    var message: String
    var subject: String
    var fields: [String: String]
    var selected: Bool = true
}

private enum DelimiterOption: String, CaseIterable, Identifiable {
    case comma = ","
    case semicolon = ";"
    case tab = "Tab"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .comma:
            return "Comma (,)"
        case .semicolon:
            return "Semicolon (;)"
        case .tab:
            return "Tab (\t)"
        case .custom:
            return "Custom"
        }
    }
}

private enum MessageMode: String, CaseIterable, Identifiable {
    case global
    case perRecipient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .global:
            return "Global message"
        case .perRecipient:
            return "Per recipient"
        }
    }
}

private struct ImportViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView: View {
    private enum FlowStep {
        case importStep
        case composeStep
    }
    
    @State private var recipients: [Recipient] = []
    @State private var defaultMessage: String = ""
    @State private var emailSubject: String = "Message for {{name}}"
    @State private var replyMail: String = ""

    @State private var ccList: String = ""
    @State private var isImporting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var delimiterOption: DelimiterOption = .semicolon
    @State private var customDelimiter: String = ""
    @State private var parsedHeaders: [String] = []
    @State private var importedRows: [[String: String]] = []
    @State private var selectedEmailHeader: String = ""
    @State private var selectedMessageHeader: String = ""
    @State private var messageMode: MessageMode = .global
    @State private var importContentHeight: CGFloat = 0
    @State private var flowStep: FlowStep = .importStep
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("MailWeave")
                    .font(.largeTitle)
                    .bold()
            }
            .padding(.top)
            
            if flowStep == .importStep {
                ImportView(
                    isImporting: $isImporting,
                    delimiterOption: $delimiterOption,
                    customDelimiter: $customDelimiter,
                    messageMode: $messageMode,
                    parsedHeaders: parsedHeaders,
                    parsedEntriesCount: importedRows.count,
                    selectedEmailHeader: $selectedEmailHeader,
                    selectedMessageHeader: $selectedMessageHeader,
                    canProceed: canProceedToCompose,
                    onImport: handleFileImport,
                    onProceed: proceedToCompose
                )
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ImportViewHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                )
            } else {
                ComposeView(
                    recipients: $recipients,
                    parsedHeaders: parsedHeaders,
                    messageMode: messageMode,
                    defaultMessage: $defaultMessage,
                    emailSubject: $emailSubject,
                    ccList: $ccList,
                    replyMail: $replyMail,
                    onBack: { flowStep = .importStep },
                    onSend: sendEmails,
                    onPrepare: composeEmails
                )
            }
            
            Spacer()
        }
        .onPreferenceChange(ImportViewHeightPreferenceKey.self) { newHeight in
            if abs(importContentHeight - newHeight) > 1 {
                importContentHeight = newHeight
            }
        }
        .frame(
            minWidth: flowStep == .composeStep ? 900 : 700,
            idealWidth: flowStep == .composeStep ? 900 : 700,
            maxWidth: .infinity,
            minHeight: currentWindowHeight,
            idealHeight: currentWindowHeight,
            maxHeight: .infinity,
            alignment: .top
        )
        .alert("MailWeave", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else { return }
            
            // Result not tested since drag and drop will return false from it
            let didStartAccessing = selectedFile.startAccessingSecurityScopedResource()
            
            guard let delimiter = selectedDelimiter() else {
                alertMessage = "Please enter a single delimiter character"
                showAlert = true
                return
            }
            
            let parser = SpreadsheetParser()
            let parseResult = parser.parseCSV(from: selectedFile, delimiter: delimiter)
            recipients = []
            importedRows = parseResult.rows
            parsedHeaders = parseResult.headers
            selectedEmailHeader = defaultHeader(preferred: "email")
            selectedMessageHeader = defaultHeader(preferred: "message")
            if didStartAccessing {
              selectedFile.stopAccessingSecurityScopedResource()
            }
            if let errorMessage = parseResult.errorMessage {
                alertMessage = errorMessage
                showAlert = true
                return
            }
            
            if importedRows.isEmpty {
                alertMessage = "No entries found in the file"
                showAlert = true
            } else {
                if messageMode == .perRecipient {
                    alertMessage = "Choose headers for email and message, then click Proceed"
                } else {
                    alertMessage = "Choose the email header, then click Proceed"
                }
                showAlert = false
            }
        } catch {
            alertMessage = "Error importing file: \(error.localizedDescription)"
            showAlert = true
        }
       

    }
    
    func sendEmails() {
       processEmail(composeOnly: false)
    }
   func composeEmails() {
     processEmail(composeOnly: true)
   }

  func processEmail(composeOnly: Bool){
    let selectedRecipients = recipients.filter { $0.selected }
    
    if selectedRecipients.isEmpty {
        alertMessage = "Please select at least one recipient"
        showAlert = true
        return
    }
    
    let emailService = EmailService()
    emailService.sendEmails(to: selectedRecipients, subject: emailSubject, cc: ccList, replyTo: replyMail, composeOnly: composeOnly) { results in
        let successCount = results.filter { $0 }.count
        let failureCount = results.count - successCount
        
        if failureCount != 0 {
            self.alertMessage = "Successfully created \(successCount) emails in Mail.app"
        } else {
            self.alertMessage = "Created \(successCount) emails. Failed: \(failureCount)"
        }
        self.showAlert = true
    }
  }
  
    private var canProceedToCompose: Bool {
        !importedRows.isEmpty &&
        !selectedEmailHeader.isEmpty &&
        (messageMode == .global || !selectedMessageHeader.isEmpty)
    }

    private var currentWindowHeight: CGFloat {
        if flowStep == .composeStep {
            return 720
        }
        return max(400, importContentHeight + 80)
    }

    private func proceedToCompose() {
        guard canProceedToCompose else {
            if messageMode == .perRecipient {
                alertMessage = "Please choose email and message headers before proceeding"
            } else {
                alertMessage = "Please choose an email header before proceeding"
            }
            showAlert = true
            return
        }

        let mappedRecipients = buildRecipients(
            rows: importedRows,
            emailHeader: selectedEmailHeader,
            messageHeader: selectedMessageHeader,
            messageMode: messageMode,
            messageSubject: emailSubject
        )

        if mappedRecipients.isEmpty {
            alertMessage = "No valid recipients found. Verify the selected email column."
            showAlert = true
            return
        }

        recipients = mappedRecipients
        if messageMode == .perRecipient, let firstMessage = mappedRecipients.first?.message, !firstMessage.isEmpty {
            defaultMessage = firstMessage
        }
        flowStep = .composeStep
    }

    private func defaultHeader(preferred: String) -> String {
        parsedHeaders.first(where: { $0 == preferred }) ?? ""
    }

    private func buildRecipients(
        rows: [[String: String]],
        emailHeader: String,
        messageHeader: String,
        messageMode: MessageMode,
        messageSubject: String
    ) -> [Recipient] {
        var mapped: [Recipient] = []

        for row in rows {
            let email = row[emailHeader, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !email.isEmpty else {
                continue
            }

            let message: String
            switch messageMode {
            case .global:
                message = ""
            case .perRecipient:
                message = row[messageHeader, default: ""]
            }
            let selectedName = row["name", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = String(email.split(separator: "@").first ?? Substring(email))
            let name = selectedName.isEmpty ? fallbackName : selectedName

            var fields = row
            fields["email"] = email
            fields["message"] = message
            fields["name"] = name

          mapped.append(Recipient(name: name, email: email, message: message, subject: messageSubject, fields: fields))
        }

        return mapped
    }
    
    private func selectedDelimiter() -> Character? {
        switch delimiterOption {
        case .comma:
            return ","
        case .semicolon:
            return ";"
        case .tab:
            return "\t"
        case .custom:
            let trimmed = customDelimiter.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count == 1, let char = trimmed.first else {
                return nil
            }
            return char
        }
    }
}

private struct ImportView: View {
    @Binding var isImporting: Bool
    @Binding var delimiterOption: DelimiterOption
    @Binding var customDelimiter: String
    @Binding var messageMode: MessageMode
    let parsedHeaders: [String]
    let parsedEntriesCount: Int
    @Binding var selectedEmailHeader: String
    @Binding var selectedMessageHeader: String
    let canProceed: Bool
    let onImport: (Result<[URL], Error>) -> Void
    let onProceed: () -> Void
    @State private var isDroppingFile: Bool = false
    @State private var hasImport: Bool = false
    private var delimiterValue: String {
        switch delimiterOption {
        case .comma:
            return ","
        case .semicolon:
            return ";"
        case .tab:
            return "\\t"
        case .custom:
            let trimmed = customDelimiter.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(invalid)" : trimmed
        }
    }

    private var messageModeValue: String {
        switch messageMode {
        case .global:
            return "global"
        case .perRecipient:
            return "per_recipient"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: { isImporting = true }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Import Spreadsheet (CSV)")
                        .background(.clear)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.commaSeparatedText, .text],
                    allowsMultipleSelection: false
                ) { result in
                    onImport(result)
                    hasImport = true
                }
                .onDrop(of: [UTType.fileURL], isTargeted: $isDroppingFile) { providers in
                    guard let provider = providers.first else { return false }
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                        guard let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        DispatchQueue.main.async {
                            onImport(.success([url]))
                          hasImport = true
                        }
                    }
                    return true
                }
              VStack(alignment: .leading, spacing: 6) {
                    Text("Delimiter")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Delimiter", selection: $delimiterOption) {
                        ForEach(DelimiterOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .frame(width: 180)
            }
            .padding(.horizontal)

            if delimiterOption == .custom {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom delimiter")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter a single delimiter character", text: $customDelimiter)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Picker("Message mode", selection: $messageMode) {
                    ForEach(MessageMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .font(.headline)
                .disabled(!hasImport)
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            if !parsedHeaders.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Header Mapping")
                        .font(.title2)
                        .bold()

                    Picker("Email header", selection: $selectedEmailHeader) {
                        Text("Select email header").tag("")
                        ForEach(parsedHeaders, id: \.self) { header in
                            Text(header).tag(header)
                        }
                    }
                    .pickerStyle(.menu)

                    if messageMode == .perRecipient {
                        Picker("Message header", selection: $selectedMessageHeader) {
                            Text("Select message header").tag("")
                            ForEach(parsedHeaders, id: \.self) { header in
                                Text(header).tag(header)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Rows parsed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(parsedEntriesCount)")
                            .font(.headline)
                    }

                    HStack {
                        Text("Headers detected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(parsedHeaders.isEmpty ? "-" : parsedHeaders.joined(separator: ", "))
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } label: {
                Text("Import Summary")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Button(action: onProceed) {
                HStack {
                    Image(systemName: "arrow.right")
                    Text("Proceed")
                    .background(.clear)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(canProceed ? Color.green : Color.gray)
            .cornerRadius(8)
            .disabled(!canProceed)
            .foregroundColor(.white)
            .padding(.horizontal)
        }
    }
}

private struct ComposeView: View {
    @Binding var recipients: [Recipient]
    let parsedHeaders: [String]
    let messageMode: MessageMode
    @Binding var defaultMessage: String
    @Binding var emailSubject: String
    @Binding var ccList: String
    @Binding var replyMail: String
    let onBack: () -> Void
    let onSend: () -> Void
    let onPrepare: () -> Void
    @State var indexFirst50 = 0
    private var availableHeaders: [String] {
        let csvHeaderSet = Set(parsedHeaders)
        var keys = Set(recipients.flatMap { $0.fields.keys })

        if !csvHeaderSet.contains("name") {
            keys.remove("name")
        }
        if !csvHeaderSet.contains("message") {
            keys.remove("message")
        }

        return keys.sorted()
    }

    private var availableHeadersDisplay: String {
        if availableHeaders.isEmpty {
            return "-"
        }
        return availableHeaders.map { "{{\($0)}}" }.joined(separator: ", ")
    }

    private var selectedCount: Int {
        recipients.filter { $0.selected }.count
    }

    private var allRecipientsSelected: Bool {
        !recipients.isEmpty && selectedCount == recipients.count
    }
    
    var body: some View {
      VStack(spacing: 20) {
          HStack {
              Button(action: onBack) {
                  HStack {
                      Image(systemName: "chevron.left")
                      Text("Back")
                  }
              }
              Spacer()
          }
          .padding(.horizontal)
          
          VStack(alignment: .leading, spacing: 8) {
            HStack{
              Text("Email Subject")
                .font(.headline)
              TextField("Subject", text: $emailSubject)
                .textFieldStyle(.roundedBorder)
                .onChange(of: emailSubject) { _ in
                  applyGlobalSubject()
                }
            }
            HStack{  Text("CC (comma-separated)")
                .font(.headline)
              HStack{   TextField("email@example.com, email2@example.com", text: $ccList)
                  .textFieldStyle(.roundedBorder)
              }
            }
            HStack{                Text("Reply to")
                .font(.headline)
              TextField("email@example.com, email2@example.com", text: $replyMail)
                .textFieldStyle(.roundedBorder)
            }
          }
          .padding(.horizontal)
          
          // Default Message Editor
          VStack(alignment: .leading, spacing: 8) {
              if messageMode == .global {
                  Text("Global Message Template")
                      .font(.headline)
                  Text("Available headers: \(availableHeadersDisplay)")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  TextEditor(text: $defaultMessage)
                      .frame(height: 140)
                      .border(Color.gray.opacity(0.5))
                      .onChange(of: defaultMessage) { _ in
                          applyGlobalMessage()
                      }
                  Text("Use {{header}} placeholders like {{name}} in the message")
                      .font(.caption)
                      .foregroundColor(.gray)
              } else {
                  Text("Per-recipient messages are loaded from the selected CSV message header.")
                      .font(.caption)
                      .foregroundColor(.secondary)
              }
          }
          .padding(.horizontal)
          
   
                // Recipients List
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recipients (\(selectedCount) selected):")
                            .font(.headline)
                        Spacer()
                        Button(allRecipientsSelected ? "Unselect all" : "Select all") {
                            setAllRecipientsSelected(!allRecipientsSelected)
                        }
                        .buttonStyle(.bordered)
                      if !allRecipientsSelected {
                        Button("select 50 next") {
                          select50next()
                        }
                        .buttonStyle(.bordered)
                      }
                     
                    }
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach($recipients) { $recipient in
                                RecipientRow(
                                    recipient: $recipient,
                                    allowMessageEditing: messageMode == .perRecipient
                                )
                            }
                        }
                    }
                    .border(Color.gray.opacity(0.3))
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
      HStack(){
        // Prepare Button
        Button(action: onPrepare) {
          HStack {
            Image(systemName: "envelope")
            Text("Prepare Emails (\(recipients.filter { $0.selected }.count))")
          }
          .frame(maxWidth: .infinity)
          .padding()
          
        }
        .background(recipients.filter { $0.selected }.isEmpty ? Color.gray : Color.green)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(recipients.filter { $0.selected }.isEmpty)
        .padding(.horizontal)
        .onAppear {
          if messageMode == .global {
            applyGlobalMessage()
          }
        }
        // Send Button
        Button(action: onSend) {
          HStack {
            Image(systemName: "envelope")
            Text("Send Emails (\(recipients.filter { $0.selected }.count))")
          }
          .frame(maxWidth: .infinity)
          .padding()
          
        }
        .background(recipients.filter { $0.selected }.isEmpty ? Color.gray : Color.green)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(recipients.filter { $0.selected }.isEmpty)
        .padding(.horizontal)
        .onAppear {
          if messageMode == .global {
            applyGlobalMessage()
          }
        }
      }
    }

    private func applyGlobalMessage() {
        for index in recipients.indices {
            recipients[index].message = defaultMessage
        }
    }
   private func applyGlobalSubject() {
      for index in recipients.indices {
          recipients[index].subject = emailSubject
      }
  }

    private func setAllRecipientsSelected(_ isSelected: Bool) {
        for index in recipients.indices {
            recipients[index].selected = isSelected
        }
      indexFirst50 = 0
    }
  
  private func select50next() {
      for index in recipients.indices {
        let isSelected = index < indexFirst50+50  && indexFirst50 <= index
        recipients[index].selected = isSelected
      }
    indexFirst50 = indexFirst50 + 50
  }
}

struct RecipientRow: View {
    @Binding var recipient: Recipient
    let allowMessageEditing: Bool
    @State private var isExpanded = false

    private var personalizedMessage: String {
        EmailService().personalizeMessage(recipient.message, fields: recipient.fields)
    }
    private var personalizedSubject: String {
      EmailService().personalizeMessage(recipient.subject, fields: recipient.fields)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $recipient.selected)
                    .labelsHidden()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipient.name)
                        .font(.headline)
                    Text(recipient.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if allowMessageEditing {
                        Text("Template:")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextEditor(text: $recipient.message)
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.5))
                    }

                    Text("Subject preview:")
                        .font(.caption)
                        .foregroundColor(.gray)
                   Text(personalizedSubject)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .padding(8)
                      .background(Color.gray.opacity(0.08))
                      .cornerRadius(6)
                  Text("Content preview:")
                      .font(.caption)
                      .foregroundColor(.gray)
 
                  Text(personalizedMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}

