import SwiftUI

struct TempoPickerView: View {
    @Binding var selectedTempo: Tempo
    let tempos: [Tempo]

    @State private var scrollID: String?

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                LazyVStack(spacing: 22) {
                    ForEach(tempos) { tempo in
                    VStack(spacing: 2) {
                        Text(tempo.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("\(tempo.defaultBPM) bpm")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.accentColor)

                        Text(tempo.description)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(height: 78)
                    .frame(maxWidth: .infinity)
                    .id(tempo.id)
                    .scaleEffect(selectedTempo.id == tempo.id ? 1.32 : 0.82)
                    .opacity(selectedTempo.id == tempo.id ? 1.0 : 0.32)
                    .shadow(
                        color: selectedTempo.id == tempo.id ? Color.accentColor.opacity(0.25) : .clear,
                        radius: selectedTempo.id == tempo.id ? 12 : 0
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTempo.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollID, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .safeAreaPadding(.vertical, geometry.size.height / 2 - 39)
        }
        .onAppear {
            scrollID = selectedTempo.id
        }
        .onChange(of: scrollID) { _, newID in
            guard let newID, let tempo = tempos.first(where: { $0.id == newID }) else { return }
            selectedTempo = tempo
        }
        .onChange(of: selectedTempo) { _, tempo in
            scrollID = tempo.id
        }
    }
}
