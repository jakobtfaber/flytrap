// Flytrap/Services/HotkeyManager.swift
import HotKey
import Carbon

final class HotkeyManager {
    private var togglePanelHotKey: HotKey?
    private var dictateHotKey: HotKey?
    private var agentPanelHotKey: HotKey?

    var onTogglePanel: (() -> Void)?
    var onToggleDictation: (() -> Void)?
    var onToggleAgentPanel: (() -> Void)?

    func register() {
        togglePanelHotKey = HotKey(key: .space, modifiers: .control)
        togglePanelHotKey?.keyDownHandler = { [weak self] in
            self?.onTogglePanel?()
        }

        dictateHotKey = HotKey(key: .space, modifiers: [.control, .shift])
        dictateHotKey?.keyDownHandler = { [weak self] in
            self?.onToggleDictation?()
        }

        agentPanelHotKey = HotKey(key: .space, modifiers: [.control, .option])
        agentPanelHotKey?.keyDownHandler = { [weak self] in
            self?.onToggleAgentPanel?()
        }
    }

    func unregister() {
        togglePanelHotKey = nil
        dictateHotKey = nil
        agentPanelHotKey = nil
    }
}
