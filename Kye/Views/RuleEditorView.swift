import SwiftUI

/// Modal sheet for adding or editing a single rule. Each key field can be filled either by
/// recording a physical key (modifier-aware, via `KeyCaptureController`) or by picking from the
/// known-key vocabulary. Save is gated by `RuleDraft.toRule()`.
struct RuleEditorView: View {
    @ObservedObject var appController: AppController
    let isEditing: Bool

    @State private var draft: RuleDraft
    @State private var errorMessage: String?
    @State private var capturingField: CaptureField?
    @State private var capture: KeyCaptureController?
    @Environment(\.dismiss) private var dismiss

    private let keyMapper = KeyMapper()

    private enum CaptureField: Equatable { case from, to, trigger, mappingFrom, mappingTo }

    init(appController: AppController, draft: RuleDraft, isEditing: Bool) {
        self.appController = appController
        self.isEditing = isEditing
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "Edit Rule" : "Add Rule")
                .font(.headline)

            Picker("Type", selection: $draft.kind) {
                Text("Remap").tag(RuleKind.basic)
                Text("Layer").tag(RuleKind.layer)
            }
            .pickerStyle(.segmented)
            .disabled(isEditing)

            TextField("Description (optional)", text: $draft.description)
                .textFieldStyle(.roundedBorder)

            if draft.kind == .basic {
                keyField("From", field: .from, selection: $draft.from)
                keyField("To", field: .to, selection: $draft.to)
            } else {
                keyField("Trigger", field: .trigger, selection: $draft.trigger)
                keyField("When held", field: .mappingFrom, selection: $draft.mappingFrom)
                keyField("Maps to", field: .mappingTo, selection: $draft.mappingTo)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 440)
        .onDisappear { capture?.cancel() }
    }

    private func keyField(_ label: String, field: CaptureField, selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 90, alignment: .leading)

            Picker("", selection: selection) {
                Text("—").tag("")
                ForEach(keyMapper.allKeyNames, id: \.self) { name in
                    Text(KeySymbol.label(for: name)).tag(name)
                }
            }
            .labelsHidden()

            Button(capturingField == field ? "Recording…" : "Record") {
                record(into: field, binding: selection)
            }
            .disabled(capturingField != nil && capturingField != field)
        }
    }

    private func record(into field: CaptureField, binding: Binding<String>) {
        capture?.cancel()
        let controller = KeyCaptureController(keyMapper: keyMapper, suspender: appController)
        capture = controller
        capturingField = field
        controller.begin { name in
            binding.wrappedValue = name
            capturingField = nil
            capture = nil
        }
    }

    private func save() {
        guard let rule = draft.toRule() else {
            errorMessage = "Fill in all required key fields."
            return
        }
        do {
            if isEditing {
                try appController.updateRule(rule)
            } else {
                try appController.addRule(rule)
            }
            dismiss()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func cancel() {
        capture?.cancel()
        dismiss()
    }
}
