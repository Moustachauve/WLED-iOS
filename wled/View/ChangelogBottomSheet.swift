import SwiftUI
import MarkdownUI

/// A "What's New" bottom sheet that presents changelog content with a
/// vibrant, native iOS design featuring animated gradient accents and
/// smooth transitions.
struct ChangelogBottomSheet: View {
    @ObservedObject var viewModel: ChangelogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    changelogBody
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .safeAreaInset(edge: .bottom) {
                dismissButton
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.dismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.title2)
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Sparkle icon with animated gradient
                sparkleIcon

                Text("What's New")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(titleGradient)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var sparkleIcon: some View {
        let icon = Image(systemName: "sparkles")
            .font(.system(size: 40, weight: .bold))
            .foregroundStyle(titleGradient)

        if #available(iOS 17.0, *) {
            icon.symbolEffect(.pulse, options: .repeating.speed(0.5))
        } else {
            icon
        }
    }

    private var titleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.orange,
                Color.pink,
                Color.purple
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Changelog Body

    @ViewBuilder
    private var changelogBody: some View {
        if let content = viewModel.changelogContent {
            Markdown(content)
                .markdownBlockStyle(\.heading1) { configuration in
                    configuration.label
                        .markdownMargin(top: 16, bottom: 8)
                        .markdownTextStyle {
                            FontWeight(.heavy)
                            ForegroundColor(.primary)
                            FontSize(24)
                        }
                }
                .markdownBlockStyle(\.heading2) { configuration in
                    configuration.label
                        .markdownMargin(top: 12, bottom: 6)
                        .markdownTextStyle {
                            FontWeight(.bold)
                            ForegroundColor(.primary)
                            FontSize(20)
                        }
                }
                .markdownBlockStyle(\.heading3) { configuration in
                    configuration.label
                        .markdownMargin(top: 8, bottom: 4)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            ForegroundColor(.secondary)
                            FontSize(17)
                        }
                }
                .markdownBlockStyle(\.thematicBreak) { _ in
                    Divider()
                        .padding(.vertical, 12)
                }
        }
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button {
            viewModel.dismiss()
            dismiss()
        } label: {
            Text("Awesome")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

#Preview("With Content") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            ChangelogBottomSheet(
                viewModel: {
                    let vm = ChangelogViewModel()
                    vm.changelogContent = """
                    # Version 42.0.0
                    
                    ### 🧠 Telepathic Toggling
                    Why use your thumbs when you can use your **brainwaves**? We've added (highly experimental) support for telepathic light control. Just think about "Orange" and watch the magic happen!
                    > *Disclaimer: May cause sudden cravings for tacos.*
                    
                    ### 🛸 Anti-Gravity Mode
                    App navigation now automatically adjusts its orientation when you are in **zero-gravity environments**. Perfect for those late-night ISS lighting adjustments.
                    
                    ---
                    
                    # Version 1.2.3-BETA
                    
                    ### 👃 Scent-Sync (Beta)
                    Added support for the upcoming *WLED-Scent* hardware. 
                    - **Fireplace effect**: Smells like toasted marshmallows.
                    - **Ocean wave**: Smells like salty sea air.
                    - **Rainbow**: Smells like... well, we're still working on that one.
                    
                    ### 🐛 Bug Squashing
                    - Fixed an issue where the app would accidentally summon a **minor storm cloud** when the brightness was set to exactly 11%.
                    - Improved connectivity for users currently roaming in **parallel dimensions**.
                    - General `under-the-hood` polish and stability for the space-time continuum.
                    """
                    return vm
                }()
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
}
