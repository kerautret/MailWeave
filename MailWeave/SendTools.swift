//
//  SendTools.swift
//  MailWeave
//
//  Created by Bertrand Kerautret on 07/06/2026.
//


import Cocoa
import Carbon.HIToolbox





// use the Standard CMD-SHIFT-D to send the email from interface
func sendShortcut() {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_ANSI_D), // D
        keyDown: true
    )
    keyDown?.flags = [.maskCommand, .maskShift]
    keyDown?.post(tap: .cghidEventTap)

    let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_ANSI_D),
        keyDown: false
    )

    keyUp?.flags = [.maskCommand, .maskShift]
    keyUp?.post(tap: .cghidEventTap)
}

