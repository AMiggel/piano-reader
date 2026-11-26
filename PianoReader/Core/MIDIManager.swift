import CoreMIDI
import Foundation
import Observation

/// Escucha todas las fuentes MIDI (USB con adaptador o Bluetooth MIDI ya emparejado).
@Observable
final class MIDIManager {
    private(set) var sources: [String] = []

    @ObservationIgnored var onNoteOn: ((Int) -> Void)?
    @ObservationIgnored var onNoteOff: ((Int) -> Void)?

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()

    /// Palabras por mensaje UMP según el tipo (4 bits altos).
    private static let umpSizes = [1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4]

    init() {
        let status = MIDIClientCreateWithBlock("PianoReader" as CFString, &client) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                DispatchQueue.main.async { self?.refresh() }
            }
        }
        guard status == noErr else { return }
        MIDIInputPortCreateWithProtocol(client, "Input" as CFString, ._1_0, &port) { [weak self] list, _ in
            self?.receive(list)
        }
        refresh()
    }

    func refresh() {
        guard port != 0 else { return }
        var names: [String] = []
        for i in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(i)
            MIDIPortDisconnectSource(port, source)
            MIDIPortConnectSource(port, source, nil)
            let name = Self.displayName(source)
            if !name.hasPrefix("Network Session") { names.append(name) }
        }
        sources = names
    }

    private func receive(_ list: UnsafePointer<MIDIEventList>) {
        var events: [(on: Bool, note: Int)] = []
        for packet in list.unsafeSequence() {
            let count = Int(packet.pointee.wordCount)
            withUnsafeBytes(of: packet.pointee.words) { raw in
                let words = raw.bindMemory(to: UInt32.self)
                var i = 0
                while i < count {
                    let word = words[i]
                    let type = Int(word >> 28)
                    if type == 0x2 { // MIDI 1.0 channel voice
                        let status = (word >> 16) & 0xF0
                        let note = Int((word >> 8) & 0x7F)
                        let velocity = word & 0x7F
                        if status == 0x90 && velocity > 0 {
                            events.append((true, note))
                        } else if status == 0x80 || status == 0x90 {
                            events.append((false, note))
                        }
                    }
                    i += Self.umpSizes[type]
                }
            }
        }
        guard !events.isEmpty else { return }
        let received = events
        DispatchQueue.main.async { [weak self] in
            for event in received {
                if event.on { self?.onNoteOn?(event.note) } else { self?.onNoteOff?(event.note) }
            }
        }
    }

    private static func displayName(_ object: MIDIObjectRef) -> String {
        var name: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(object, kMIDIPropertyDisplayName, &name) == noErr,
           let value = name?.takeRetainedValue() {
            return value as String
        }
        return "Dispositivo MIDI"
    }
}
