import SwiftUI

struct TicketsTab: View {
    @Binding var project: Project
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(project.tickets.sorted(by: { $0.createdAt > $1.createdAt })) { ticket in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                TicketKindBadge(kind: ticket.kind)
                                Text(ticket.title)
                                    .font(.title3.weight(.semibold))
                                Spacer()
                                Button {
                                    Task { await workspace.launchTicket(ticket) }
                                } label: {
                                    Label("Агент", systemImage: "bolt.fill")
                                }
                                .brGlass()
                            }
                            Text(ticket.body)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                            if !ticket.affectedEntities.isEmpty {
                                Label(ticket.affectedEntities.joined(separator: ", "), systemImage: "cylinder.split.1x2")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let message = workspace.agentLaunchMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
    }
}
