import SwiftUI

enum CardStyle {
    case `default`
    case device(color: Color)
}

struct Card<Content: View>: View {
    let style: CardStyle
    let content: Content

    init(style: CardStyle = .default, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .default:
            Color(UIColor.secondarySystemBackground)
        case .device(let color):
            ZStack {
                Rectangle().fill(color)
                Rectangle().fill(.thickMaterial)
            }
        }
    }
}

// MARK: - CardGroupBoxStyle

struct CardGroupBoxStyle: GroupBoxStyle {
    let style: CardStyle

    func makeBody(configuration: Configuration) -> some View {
        Card(style: style) {
            VStack(alignment: .leading, spacing: 8) {
                configuration.label
                configuration.content
            }
        }
    }
}

struct Card_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Card {
                Text("Default Card")
            }
            Card(style: .device(color: .blue)) {
                Text("Device Card")
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
