import Defaults
import SecurePasteKit
import SwiftUI
import UniformTypeIdentifiers

struct SecurePasteSettingsView: View {
  @Default(.secureApplications) private var applications
  @State private var selection: String?
  @State private var adding = false
  @State private var importMessage = ""
  private let security = SecurePasteService.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("SecurePaste — sans presse-papiers", systemImage: "lock.shield")
        .font(.headline)
      Label(security.isOperational ? "Interception active" : "Protection indisponible",
            systemImage: security.isOperational ? "checkmark.shield" : "exclamationmark.triangle")
        .foregroundStyle(security.isOperational ? Color.primary : Color.orange)
      Text(security.message).fixedSize(horizontal: false, vertical: true)
      if security.remainingSeconds > 0 {
        Text("Secret disponible : \(security.remainingSeconds) s")
          .monospacedDigit()
      }
      HStack {
        Button("Autoriser l’accessibilité") { security.requestAccessibility() }
        Button("Détruire le secret") { security.clear() }
          .disabled(security.remainingSeconds == 0)
      }
      Divider()
      Text("Applications utilisant ⌘C et ⌘V sécurisés").font(.headline)
      List(selection: $selection) {
        ForEach(applications, id: \.self) { identifier in
          VStack(alignment: .leading) {
            Text(applicationName(identifier))
            Text(identifier).font(.caption).foregroundStyle(.secondary)
          }.tag(identifier)
        }
      }.frame(height: 150)
      HStack {
        Button("Ajouter une application…") { adding = true }
        Button("Retirer") {
          applications.removeAll { $0 == selection }
          selection = nil
        }.disabled(selection == nil)
      }
      Text("Ailleurs : ⇧⌘C pour capturer et ⇧⌘V pour insérer. L’historique s’ouvre avec ⌃⌥⌘H par défaut.")
        .fixedSize(horizontal: false, vertical: true)
      Text("Un secret, 60 s maximum, détruit après insertion ou nouvelle copie. Sans Touch ID. Rouge : secret disponible. Vert pendant 1,5 s : insertion réussie et secret détruit. Gris : aucun secret.")
        .fixedSize(horizontal: false, vertical: true)
      Text("Les menus Copier/Coller et les champs AX incompatibles ne sont pas protégés. Si l’interception est indisponible, ⌘C peut rester classique : vérifier l’indicateur avant toute copie sensible.")
        .font(.callout).fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.secondary)
      if !importMessage.isEmpty { Text(importMessage).foregroundStyle(.secondary) }
    }
    .padding(20)
    .frame(width: 550)
    .fileImporter(isPresented: $adding, allowedContentTypes: [.application]) { result in
      if case .success(let url) = result {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let identifier = Bundle(url: url)?.bundleIdentifier,
           identifier != Bundle.main.bundleIdentifier {
          if !applications.contains(identifier) { applications.append(identifier) }
          importMessage = ""
        } else {
          importMessage = "Choisir une autre application macOS valide."
        }
      }
    }
  }

  private func applicationName(_ identifier: String) -> String {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
      return identifier
    }
    return NSWorkspace.shared.applicationName(url: url)
  }
}
