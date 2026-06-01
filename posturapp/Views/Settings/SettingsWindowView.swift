import SwiftUI

struct SettingsWindowView: View {

    @EnvironmentObject var postureAnalyzer: PostureAnalyzer
    @EnvironmentObject var poseDetector: PoseDetector
    @EnvironmentObject var statsStore: PostureStatsStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
        }
        .frame(minWidth: 560, minHeight: 460)
        .padding()
    }
}
