import Foundation
import Testing
import LecternCore
@testable import Lectern

/// L-FUNC-1: a "(soon)" label warned but never stopped a tap — a user could
/// select Gemini or Custom, paste a real key, save it, and only discover the
/// provider can't run when Generate throws. `ProviderPicker` is the fix:
/// `selectable` is the option list Settings actually offers (unwired
/// providers excluded, not merely labelled), and `resolveStoredSelection`
/// is what keeps a *previously* stored unwired selection from landing the
/// Picker on a tag it no longer offers (which renders blank/undefined).
///
/// Both are plain, pure functions — tested directly here rather than through
/// `SettingsView` itself, which a bare unit test cannot host (no live SwiftUI
/// hierarchy), matching this codebase's existing pattern of factoring
/// view-adjacent decisions out into testable helpers (see
/// `DeckDeletionRequest` in `LibraryView.swift`).
@Suite struct ProviderPickerTests {
    @Test func selectableExcludesUnwiredProvidersEntirely() {
        let options = ProviderPicker.selectable

        #expect(!options.contains(.gemini))
        #expect(!options.contains(.custom))
        #expect(options.contains(.anthropic))
        #expect(options.contains(.openAI))
    }

    @Test func selectableOnlyEverContainsWiredProviders() {
        // Not hard-coded to today's two wired providers: if `isWired` grows
        // or shrinks, `selectable` must track it exactly.
        for id in ProviderPicker.selectable {
            #expect(ProviderFactory.isWired(id))
        }
    }

    @Test func selectableIncludesEveryWiredProvider() {
        // The converse of the above: nothing wired is missing from the list.
        for id in ProviderID.allCases where ProviderFactory.isWired(id) {
            #expect(ProviderPicker.selectable.contains(id))
        }
    }

    @Test func resolveStoredSelectionKeepsAnAlreadyWiredProvider() {
        #expect(ProviderPicker.resolveStoredSelection(.anthropic) == .anthropic)
        #expect(ProviderPicker.resolveStoredSelection(.openAI) == .openAI)
    }

    @Test func resolveStoredSelectionMigratesAnUnwiredStoredProviderToTheDefault() {
        // The scenario this exists for: a user selected Gemini (or Custom)
        // before this gate shipped, and it is still sitting in UserDefaults.
        #expect(ProviderPicker.resolveStoredSelection(.gemini) == .anthropic)
        #expect(ProviderPicker.resolveStoredSelection(.custom) == .anthropic)
    }

    @Test func resolveStoredSelectionHonorsAnExplicitFallback() {
        // The default fallback is `.anthropic`, but the decision is generic —
        // it migrates to whichever wired provider is asked for.
        #expect(ProviderPicker.resolveStoredSelection(.gemini, fallback: .openAI) == .openAI)
    }

    @Test func resolveStoredSelectionNeverReturnsAnUnwiredProvider() {
        // Whatever comes in, whatever the fallback, the UI must never be
        // handed a selection it can neither show nor run.
        for stored in ProviderID.allCases {
            #expect(ProviderFactory.isWired(ProviderPicker.resolveStoredSelection(stored)))
        }
    }
}
