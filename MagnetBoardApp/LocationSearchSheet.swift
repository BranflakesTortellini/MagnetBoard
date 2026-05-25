import SwiftUI
import MapKit

/// Search/pick UI used by both the new-card form and card-detail editor.
/// Users are not forced to choose an exact place; this simply makes Maps ETA easy.
struct LocationSearchSheet: View {
    @StateObject private var viewModel: LocationSearchViewModel

    let onSelect: (LocationSearchResult) -> Void
    let onCancel: () -> Void

    init(initialQuery: String,
         onSelect: @escaping (LocationSearchResult) -> Void,
         onCancel: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LocationSearchViewModel(initialQuery: initialQuery))
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Place, address, or neighborhood", text: $viewModel.query)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit { viewModel.search() }
                        Button("Search") { viewModel.search() }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Toggle("Search near \(viewModel.searchBiasName)", isOn: $viewModel.useSearchBias)
                } footer: {
                    Text("Choose an exact place when you want Maps ETA/route support. You can also cancel and keep a loose text-only location. Turn this off when planning somewhere else, or change the default search area in Settings.")
                }

                if viewModel.isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching…")
                    }
                }

                if let message = viewModel.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Results") {
                    ForEach(viewModel.results) { result in
                        Button {
                            onSelect(result)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.name)
                                        .font(.body.weight(.semibold))
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Find Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}
