// Dosya: TarihAraligiSecimView.swift

import SwiftUI

struct TarihAraligiSecimView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filtreAyarlari: FiltreAyarlari

    var body: some View {
        NavigationStack {
            Form {
                ozelAralikSection
                hazirAraliklarSection
            }
            .navigationTitle("filter.date_range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.reset") { selectPreset(.buAy) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.apply") { dismiss() }
                }
            }
        }
    }
    
    private var ozelAralikSection: some View {
        Section(header: Text("filter.custom_range_header")) {
            DatePicker("filter.start_date", selection: dateBinding(for: .start), in: ...dateBinding(for: .end).wrappedValue, displayedComponents: .date)
            DatePicker("filter.end_date", selection: dateBinding(for: .end), in: (filtreAyarlari.baslangicTarihi ?? .distantPast)..., displayedComponents: .date)
        }
    }
    
    private var hazirAraliklarSection: some View {
        List {
            ForEach(TarihAraligi.allCases.filter { $0 != .ozel }, id: \.self) { aralik in
                Button(action: { selectPreset(aralik) }) {
                    HStack {
                        Text(LocalizedStringKey(aralik.rawValue)).foregroundColor(.primary)
                        Spacer()
                        if filtreAyarlari.tarihAraligi == aralik {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
    }
    
    private func selectPreset(_ aralik: TarihAraligi) {
        filtreAyarlari.tarihAraligi = aralik
        if let interval = aralik.dateInterval() {
            filtreAyarlari.baslangicTarihi = interval.start
            let calendar = Calendar.current
            let endOfInterval = interval.end
            
            if aralik == .buAy || aralik == .buHafta {
                 filtreAyarlari.bitisTarihi = calendar.date(byAdding: .day, value: -1, to: endOfInterval)
            } else {
                 filtreAyarlari.bitisTarihi = endOfInterval
            }
        }
    }
    
    private enum DateType { case start, end }
    private func dateBinding(for type: DateType) -> Binding<Date> {
        Binding<Date>(
            get: {
                switch type {
                case .start: return filtreAyarlari.baslangicTarihi ?? Date()
                case .end: return filtreAyarlari.bitisTarihi ?? Date()
                }
            },
            set: { newDate in
                switch type {
                case .start:
                    filtreAyarlari.baslangicTarihi = newDate
                    if let bitis = filtreAyarlari.bitisTarihi, newDate > bitis {
                        filtreAyarlari.bitisTarihi = newDate
                    }
                case .end:
                    filtreAyarlari.bitisTarihi = newDate
                }
                filtreAyarlari.tarihAraligi = .ozel
            }
        )
    }
}
