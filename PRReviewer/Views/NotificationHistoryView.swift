import SwiftUI

struct NotificationHistoryView: View {
    @StateObject private var historyManager = NotificationHistoryManager.shared
    let onSelectNotification: (NotificationTarget) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notifications")
                    .font(.title2.bold())
                    .foregroundColor(GruvboxColors.fg0)

                Spacer()

                if !historyManager.items.isEmpty {
                    Button {
                        historyManager.markAllAsRead()
                    } label: {
                        Text("Mark All Read")
                            .font(.caption)
                            .foregroundColor(GruvboxColors.aquaLight)
                    }
                }
            }
            .padding()
            .background(GruvboxColors.bg0)

            if historyManager.items.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(GruvboxColors.fg4)

                    Text("No notifications yet")
                        .font(.headline)
                        .foregroundColor(GruvboxColors.fg3)

                    Text("Swipe right to see PRs")
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Notification list
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(historyManager.items) { item in
                            NotificationRowView(item: item) {
                                historyManager.markAsRead(item)
                                onSelectNotification(item.target)
                            }
                        }
                    }
                }
            }
        }
        .background(GruvboxColors.bg0)
    }
}

struct NotificationRowView: View {
    let item: NotificationHistoryItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Unread indicator
                Circle()
                    .fill(item.isRead ? Color.clear : GruvboxColors.aquaLight)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 4) {
                    // Title (repo #number)
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(item.isRead ? GruvboxColors.fg3 : GruvboxColors.fg0)
                        .lineLimit(1)

                    // Body (emoji + author: message)
                    Text(item.body)
                        .font(.caption)
                        .foregroundColor(item.isRead ? GruvboxColors.fg4 : GruvboxColors.fg2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Timestamp
                    Text(item.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(GruvboxColors.fg4)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(GruvboxColors.fg4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(item.isRead ? GruvboxColors.bg0 : GruvboxColors.bg1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NotificationHistoryView { _ in }
}
