import CoreAudioKit
import SwiftUI

/// Pantalla del sistema para emparejar dispositivos Bluetooth MIDI (no funciona en el simulador).
struct BluetoothMIDIView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let central = CABTMIDICentralViewController()
        let dismiss = self.dismiss
        central.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { _ in dismiss() }
        )
        return UINavigationController(rootViewController: central)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}
