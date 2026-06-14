import Foundation
import AppKit

class EmailService {
  func sendEmails(to recipients: [Recipient], subject: String, cc: String, replyTo: String, composeOnly: Bool, completion: @escaping ([Bool]) -> Void) {
          var results: [Bool] = []
      if !composeOnly {
        guard self.ensureAccessibilityPermission() else {
              return
          }
      }
        // Send emails asynchronously to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async {
            for recipient in recipients {
                let resolvedSubject = self.personalizeMessage(subject, fields: recipient.fields)
                let resolvedCc = self.personalizeMessage(cc, fields: recipient.fields)
                let body = self.personalizeMessage(recipient.message, fields: recipient.fields)
                let success = self.createEmailInMailApp(
                    to: recipient.email,
                    cc: resolvedCc,
                    replyTo: replyTo,
                    subject: resolvedSubject,
                    body: body
                )
              results.append(success)
              // Small delay to prevent overwhelming the system
              Thread.sleep(forTimeInterval: composeOnly ? 0.5 : 1)
              if !composeOnly {
                // UI automation must run on main thread
                DispatchQueue.main.sync {
                  // Ensure Mail is frontmost before sending shortcut
                  NSRunningApplication.runningApplications(
                    withBundleIdentifier: "com.apple.mail"
                  ).first?.activate(options: [.activateIgnoringOtherApps])
                  sendShortcut()
                }
              }
            }
            
            // Call completion handler on main thread
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
  private func ensureAccessibilityPermission() -> Bool {
      let options: NSDictionary = [
          kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
      ]
      let trusted = AXIsProcessTrustedWithOptions(options)
      if !trusted {
          showAccessibilityAlert()
      }
      return trusted
  }

  private func showAccessibilityAlert() {
      let alert = NSAlert()
      alert.messageText = "Accessibility Permission Required"
      alert.informativeText = """
      To automatically send emails, this app needs Accessibility permission.

      Go to:
      System Settings → Privacy & Security → Accessibility

      Then enable access for this app.
      """

      alert.alertStyle = .warning
      alert.addButton(withTitle: "Open Settings")
      alert.addButton(withTitle: "Cancel")
      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
          if let url = URL(
              string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
          ) {
              NSWorkspace.shared.open(url)
          }
      }
  }

    func personalizeMessage(_ message: String, fields: [String: String]) -> String {
        let normalizedFields = normalizeFieldMap(fields)
        return replacePlaceholders(in: message, fields: normalizedFields)
    }
    
    private func replacePlaceholders(in message: String, fields: [String: String]) -> String {
        var result = message
        var searchRange = result.startIndex..<result.endIndex
        
        while let openRange = result.range(of: "{{", range: searchRange) {
            guard let closeRange = result.range(of: "}}", range: openRange.upperBound..<result.endIndex) else {
                break
            }
            let rawKey = String(result[openRange.upperBound..<closeRange.lowerBound])
            let key = normalizePlaceholderKey(rawKey)
            if let replacement = fields[key] {
                result.replaceSubrange(openRange.lowerBound..<closeRange.upperBound, with: replacement)
                searchRange = openRange.lowerBound..<result.endIndex
            } else {
                searchRange = closeRange.upperBound..<result.endIndex
            }
        }
        
        return result
    }
    
    private func normalizeFieldMap(_ fields: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (key, value) in fields {
            let normalizedKey = normalizePlaceholderKey(key)
            if normalized[normalizedKey] == nil {
                normalized[normalizedKey] = value
            }
        }
        return normalized
    }
    
    private func normalizePlaceholderKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutBom = trimmed.replacingOccurrences(of: "\u{FEFF}", with: "")
        let collapsed = withoutBom.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let withoutBraces = stripPlaceholderBraces(from: collapsed)
        return sanitizeKey(withoutBraces)
    }
    
    private func sanitizeKey(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: " _-"))
        let filtered = String(key.unicodeScalars.filter { allowed.contains($0) })
        let collapsed = filtered.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.lowercased()
    }
    
    private func stripPlaceholderBraces(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{{"), trimmed.hasSuffix("}}") else { return trimmed }
        let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
        let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
        let inner = String(trimmed[start..<end])
        return inner.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func createEmailInMailApp(to: String, cc: String, replyTo: String, subject: String, body: String) -> Bool {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        
        var queryItems: [URLQueryItem] = []
        if !subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        let normalizedReplyTo = replyTo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedReplyTo.isEmpty {
            queryItems.append(URLQueryItem(name: "reply-to", value: normalizedReplyTo))
        }
        if !body.isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        let normalizedCc = cc
            .replacingOccurrences(of: ";", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        if !normalizedCc.isEmpty {
            queryItems.append(URLQueryItem(name: "cc", value: normalizedCc))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let mailtoURL = components.url else {
            return false
        }
        
        // Open the URL in Mail.app (must be called on main thread)
        _ = DispatchQueue.main.sync {
            NSWorkspace.shared.open(mailtoURL)
        }
        
        return true
    }
}

