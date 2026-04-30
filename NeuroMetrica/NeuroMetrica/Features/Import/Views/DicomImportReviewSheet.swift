import SwiftUI

struct DicomImportReviewSheet: View {
    @ObservedObject var viewModel: ImportViewModel
    let session: DicomImportReviewSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session.options) { option in
                        optionCard(option)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    viewModel.dismissPendingDicomReview()
                }

                Spacer()

                Button("Load Selected Series") {
                    viewModel.confirmPendingDicomReview()
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.selectedOption == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 460)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review DICOM Import")
                .font(.title2.weight(.semibold))

            Text(session.sourceURL.lastPathComponent)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(headerMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var headerMessage: String {
        if session.inspection.isAmbiguous {
            return "Multiple DICOM candidates were detected. Choose the series stack to load."
        }
        return "The recommended DICOM stack has geometry warnings. Review it before loading."
    }

    private func optionCard(_ option: DicomImportOption) -> some View {
        let isSelected = session.selectedOptionID == option.id

        return Button {
            viewModel.selectPendingDicomReviewOption(id: option.id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if option.isRecommended {
                                statusBadge("Recommended", color: .accentColor)
                            }

                            if option.requiresAttention {
                                statusBadge("Review", color: .orange)
                            }
                        }

                        Text(option.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let studyDescription = option.studyDescription,
                           !studyDescription.isEmpty,
                           studyDescription != option.title {
                            Text(studyDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if option.requiresAttention {
                            VStack(alignment: .leading, spacing: 4) {
                                if option.orientationConsistent == false {
                                    warningLine("Slice orientation is inconsistent across images.")
                                }
                                if option.spacingUniform == false {
                                    warningLine("Slice spacing is not uniform.")
                                }
                                ForEach(option.displayReasons, id: \.self) { reason in
                                    warningLine(reason)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private func warningLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
