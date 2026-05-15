import Foundation

struct Tempo: Identifiable, Hashable {
    let id: String
    let name: String
    let defaultBPM: Int
    let range: ClosedRange<Int>
    let description: String

    static func nearest(to bpm: Int) -> Tempo {
        all.min { abs($0.defaultBPM - bpm) < abs($1.defaultBPM - bpm) }!
    }

    static let all: [Tempo] = [
        Tempo(id: "larghissimo", name: "Larghissimo", defaultBPM: 20, range: 16...24, description: "extremely slow"),
        Tempo(id: "grave",       name: "Grave",       defaultBPM: 30, range: 25...40, description: "slow and solemn"),
        Tempo(id: "lento",       name: "Lento",       defaultBPM: 42, range: 40...48, description: "slowly"),
        Tempo(id: "largo",       name: "Largo",       defaultBPM: 48, range: 44...52, description: "broadly"),
        Tempo(id: "larghetto",   name: "Larghetto",   defaultBPM: 54, range: 50...60, description: "rather broadly"),
        Tempo(id: "adagio",      name: "Adagio",      defaultBPM: 62, range: 55...68, description: "slow and stately"),
        Tempo(id: "adagietto",   name: "Adagietto",   defaultBPM: 67, range: 64...72, description: "rather slow"),
        Tempo(id: "andante",     name: "Andante",     defaultBPM: 75, range: 69...80, description: "at a walking pace"),
        Tempo(id: "andantino",   name: "Andantino",   defaultBPM: 80, range: 76...88, description: "slightly faster than andante"),
        Tempo(id: "moderato",    name: "Moderato",    defaultBPM: 92, range: 86...100, description: "moderately"),
        Tempo(id: "allegretto",  name: "Allegretto",  defaultBPM: 104, range: 98...116, description: "moderately fast"),
        Tempo(id: "allegro",     name: "Allegro",     defaultBPM: 132, range: 116...156, description: "fast and bright"),
        Tempo(id: "vivace",      name: "Vivace",      defaultBPM: 164, range: 152...176, description: "lively and fast"),
        Tempo(id: "presto",      name: "Presto",      defaultBPM: 180, range: 168...200, description: "very fast"),
        Tempo(id: "prestissimo", name: "Prestissimo", defaultBPM: 208, range: 200...240, description: "extremely fast"),
    ]
}
