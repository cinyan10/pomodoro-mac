import Carbon

final class HotKeyManager {
    enum Action {
        case startFocus
        case startRest
        case stop
    }

    private enum HotKeyID: UInt32 {
        case focusF19 = 1
        case restF19 = 2
        case stopF19 = 3
    }

    private let handler: (Action) -> Void
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    init(handler: @escaping (Action) -> Void) {
        self.handler = handler
    }

    deinit {
        unregister()
    }

    func register() -> [String] {
        installEventHandler()

        return [
            registerHotKey(id: .focusF19, keyCode: UInt32(kVK_F19), modifiers: UInt32(controlKey), label: "Control-F19"),
            registerHotKey(id: .restF19, keyCode: UInt32(kVK_F19), modifiers: UInt32(optionKey), label: "Option-F19"),
            registerHotKey(id: .stopF19, keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey), label: "Command-F19")
        ].compactMap { $0 }
    }

    func unregister() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func registerHotKey(id: HotKeyID, keyCode: UInt32, modifiers: UInt32, label: String) -> String? {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id.rawValue)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            return nil
        }

        hotKeyRefs.append(hotKeyRef)
        return label
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return status
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handle(hotKeyID)
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    private func handle(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == Self.signature else {
            return
        }

        switch hotKeyID.id {
        case HotKeyID.focusF19.rawValue:
            handler(.startFocus)
        case HotKeyID.restF19.rawValue:
            handler(.startRest)
        case HotKeyID.stopF19.rawValue:
            handler(.stop)
        default:
            break
        }
    }

    private static let signature: OSType = {
        let bytes = Array("Pomo".utf8)
        return bytes.reduce(0) { ($0 << 8) + OSType($1) }
    }()
}
