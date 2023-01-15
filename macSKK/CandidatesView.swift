// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel

    var body: some View {
        // Listではスクロールが生じるためForEachを使用
        VStack(alignment: .leading, spacing: 0) {
            ForEach(candidates.candidates.indices, id: \.self) { index in
                VStack {
                    Spacer()
                    HStack {
                        Text("\(index + 1)")
                        Text(candidates.candidates[index].word)
                        Spacer()
                    }
                    .background(candidates.candidates[index] == candidates.selected ? Color.accentColor : nil)
                    Spacer()
                }.frame(height: 20)
            }
        }
    }
}

struct CandidatesView_Previews: PreviewProvider {
    private static let words: [Word] = (0..<9).map { Word(String(repeating: "例文\($0)", count: $0)) }

    static var previews: some View {
        CandidatesView(candidates: CandidatesViewModel(candidates: words))
    }
}
