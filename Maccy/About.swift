import Cocoa

class About {
  private var links: NSMutableAttributedString {
    let string = NSMutableAttributedString(string: "SecurePaste — fork de Maccy\nGitHub SecurePaste · Projet Maccy",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    let text = string.string as NSString
    string.addAttribute(.link, value: "https://github.com/AntoineViallefont/Maccy",
                        range: text.range(of: "GitHub SecurePaste"))
    string.addAttribute(.link, value: "https://github.com/p0deje/Maccy",
                        range: text.range(of: "Projet Maccy"))
    return string
  }

  private var credits: NSMutableAttributedString {
    let credits = NSMutableAttributedString(string: "",
                                            attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    credits.append(links)
    credits.append(NSAttributedString(string: "\n\nLogiciel d’origine sous licence MIT."))
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    return credits
  }

  @objc
  func openAbout(_ sender: NSMenuItem?) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
  }
}
