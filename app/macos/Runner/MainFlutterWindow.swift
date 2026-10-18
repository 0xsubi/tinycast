import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = NSColor(white: 0.04, alpha: 1)
    self.contentViewController = flutterViewController

    // Room for the deck at a comfortable size, centred on first launch.
    self.title = "tinycast"
    self.setContentSize(NSSize(width: 1240, height: 880))
    self.contentMinSize = NSSize(width: 640, height: 480)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
