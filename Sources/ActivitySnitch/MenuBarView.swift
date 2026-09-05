import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var state = MonitorState.shared

    @AppStorage(SettingsKey.threshold) private var threshold = 200.0
    @AppStorage(SettingsKey.sustainMinutes) private var sustainMinutes = 2.0
    @AppStorage(SettingsKey.onlyOnBattery) private var onlyOnBattery = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: state.isOnBattery ? "battery.50percent" : "powerplug.fill")
                Text(state.isOnBattery ? "On battery" : "AC power")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.callout)

            if state.notificationsDenied {
                Label(
                    "Notifications are disabled — allow them in System Settings.",
                    systemImage: "bell.slash"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Divider()

            Text("Top energy impact (avg over \(formattedWindow))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if state.topConsumers.isEmpty {
                Text("Sampling…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.topConsumers) { consumer in
                    HStack {
                        Text(consumer.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(String(format: "%.0f", consumer.average))
                            .monospacedDigit()
                            .foregroundStyle(consumer.average >= threshold ? .red : .primary)
                        // Fixed-width slot so the numbers stay aligned whether
                        // or not the quit button is showing.
                        Group {
                            if consumer.average >= threshold {
                                Button {
                                    ProcessTerminator.shared.terminate(
                                        consumer.key, name: consumer.name)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .help(
                                    "Quit \(consumer.name) — asks nicely first, force-quits after 60 s"
                                )
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: 16, height: 16)
                    }
                    .font(.callout)
                }
            }

            Divider()

            HStack {
                Text("Threshold")
                Spacer()
                TextField("", value: $threshold, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Stepper("", value: $threshold, in: 10...5000, step: 10)
                    .labelsHidden()
            }
            .font(.callout)

            HStack {
                Text("Sustained for (min)")
                Spacer()
                TextField("", value: $sustainMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Stepper("", value: $sustainMinutes, in: 0.5...60, step: 0.5)
                    .labelsHidden()
            }
            .font(.callout)

            Toggle("Only notify on battery", isOn: $onlyOnBattery)
                .font(.callout)

            Divider()

            Button("Quit ActivitySnitch") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private var formattedWindow: String {
        sustainMinutes == 1 ? "1 min" : String(format: "%g min", sustainMinutes)
    }
}
