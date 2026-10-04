import SwiftUI

struct SwipeAction: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    let handler: () -> Void

    var id: String { title }
}

struct SwipeActionRow<Content: View>: View {
    let rowID: UUID
    @Binding var openRowID: UUID?
    let actions: [SwipeAction]
    let cornerRadius: CGFloat
    let onTap: () -> Void
    let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var gestureAxis: Axis?
    @State private var tapBlockedUntil = Date.distantPast

    private let actionWidth: CGFloat = 80

    init(
        rowID: UUID,
        openRowID: Binding<UUID?>,
        actions: [SwipeAction],
        cornerRadius: CGFloat = 16,
        onTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.rowID = rowID
        self._openRowID = openRowID
        self.actions = actions
        self.cornerRadius = cornerRadius
        self.onTap = onTap
        self.content = content()
    }

    private var revealWidth: CGFloat {
        actionWidth * CGFloat(actions.count)
    }

    private var isOpen: Bool {
        openRowID == rowID
    }

    private var currentOffset: CGFloat {
        let base: CGFloat = isOpen ? -revealWidth : 0
        let proposed = base + dragOffset
        return min(0, max(proposed, -revealWidth - 24))
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            .offset(x: currentOffset)
            .frame(maxWidth: .infinity)
            .background(alignment: .trailing) {
                actionButtons
                    .opacity(currentOffset < -1 ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .simultaneousGesture(dragGesture)
    }

    private var actionButtons: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                Button {
                    close()
                    action.handler()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: action.systemImage)
                            .font(.title3)
                        Text(action.title)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(action.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if gestureAxis == nil {
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    gestureAxis = isHorizontal ? .horizontal : .vertical
                    if isHorizontal {
                        tapBlockedUntil = .distantFuture
                        if let open = openRowID, open != rowID {
                            withAnimation(.smooth) {
                                openRowID = nil
                            }
                        }
                    }
                }
                guard gestureAxis == .horizontal else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                defer { gestureAxis = nil }
                guard gestureAxis == .horizontal else { return }

                tapBlockedUntil = Date().addingTimeInterval(0.3)

                let base: CGFloat = isOpen ? -revealWidth : 0
                let predicted = base + value.predictedEndTranslation.width
                let shouldOpen = predicted < -revealWidth * 0.5

                withAnimation(.smooth) {
                    if shouldOpen {
                        openRowID = rowID
                    } else if isOpen {
                        openRowID = nil
                    }
                    dragOffset = 0
                }
            }
    }

    private func handleTap() {
        guard gestureAxis == nil, Date() >= tapBlockedUntil else { return }
        if isOpen {
            close()
        } else {
            onTap()
        }
    }

    private func close() {
        withAnimation(.smooth) {
            if openRowID == rowID {
                openRowID = nil
            }
            dragOffset = 0
        }
    }
}
