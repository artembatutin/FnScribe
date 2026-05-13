//
//  DashboardTheme.swift
//  FnScribe
//
//  Created by Codex on 2026-04-22.
//

import SwiftUI

enum DashboardMetrics {
    static let contentPadding: CGFloat = 18
    static let sidebarPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 14
    static let stackSpacing: CGFloat = 10
    static let controlGap: CGFloat = 8
    static let surfaceRadius: CGFloat = 14
    static let controlRadius: CGFloat = 10
    static let controlHeight: CGFloat = 34
    static let minHitArea: CGFloat = 40
}

enum DashboardPalette {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceSecondary = Color(nsColor: .textBackgroundColor)
    static let surfaceTertiary = Color(nsColor: .unemphasizedSelectedTextBackgroundColor)
    static let outlineSoft = Color(nsColor: .separatorColor).opacity(0.34)
    static let gridLine = Color(nsColor: .separatorColor).opacity(0.28)
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .labelColor).opacity(0.82)
    static let textMuted = Color(nsColor: .labelColor).opacity(0.64)
    static let accentBlue = Color(nsColor: .controlAccentColor)
    static let accentCyan = Color(nsColor: .systemTeal)
    static let accentAmber = Color(nsColor: .systemOrange)
    static let accentRose = Color(nsColor: .systemPink)
    static let accentGreen = Color(nsColor: .systemGreen)
    static let destructive = Color(nsColor: .systemRed)
    static let shadow = Color.black.opacity(0.05)
}

struct DashboardSceneBackground: View {
    var body: some View {
        DashboardPalette.background
            .ignoresSafeArea()
    }
}

struct DashboardSurface<Content: View>: View {
    let padding: CGFloat
    let radius: CGFloat
    let secondary: Bool
    @ViewBuilder var content: Content

    init(
        padding: CGFloat = DashboardMetrics.stackSpacing,
        radius: CGFloat = DashboardMetrics.surfaceRadius,
        secondary: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.secondary = secondary
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(secondary ? DashboardPalette.surfaceSecondary : DashboardPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
                    )
            }
            .shadow(color: DashboardPalette.shadow, radius: 4, x: 0, y: 1)
    }
}

struct DashboardPanel<Content: View>: View {
    let padding: CGFloat
    let radius: CGFloat
    let secondary: Bool
    @ViewBuilder var content: Content

    init(
        padding: CGFloat = 18,
        radius: CGFloat = 18,
        secondary: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.secondary = secondary
        self.content = content()
    }

    var body: some View {
        DashboardSurface(padding: padding, radius: radius, secondary: secondary) {
            content
        }
    }
}

struct DashboardToolbar<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder var content: Content

    init(
        padding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        DashboardSurface(
            padding: padding,
            radius: DashboardMetrics.surfaceRadius,
            secondary: true
        ) {
            content
        }
    }
}

struct DashboardControlSurface<Content: View>: View {
    let height: CGFloat?
    let padding: CGFloat
    let radius: CGFloat
    let emphasize: Bool
    @ViewBuilder var content: Content

    init(
        height: CGFloat? = DashboardMetrics.controlHeight,
        padding: CGFloat = 10,
        radius: CGFloat = DashboardMetrics.controlRadius,
        emphasize: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.padding = padding
        self.radius = radius
        self.emphasize = emphasize
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, padding)
            .frame(height: height, alignment: .center)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(emphasize ? DashboardPalette.surfaceTertiary.opacity(0.55) : DashboardPalette.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
                    )
            }
    }
}

struct DashboardSectionHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions

    init(
        title: String,
        subtitle: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DashboardPalette.textPrimary)
                    .textSelection(.enabled)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DashboardPalette.textSecondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 16)

            actions
        }
    }
}

extension DashboardSectionHeader where Actions == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct DashboardSidebarRow: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(selected ? DashboardPalette.accentBlue : Color.clear)
                    .frame(width: 3, height: 20)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? DashboardPalette.accentBlue : DashboardPalette.textSecondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundStyle(DashboardPalette.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(backgroundColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if selected {
            return DashboardPalette.accentBlue.opacity(0.10)
        }
        return isHovering ? DashboardPalette.surfaceTertiary.opacity(0.22) : Color.clear
    }
}

struct DashboardStatBadge: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        DashboardControlSurface(padding: 9) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DashboardPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)

                Spacer(minLength: 6)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DashboardPalette.textPrimary)
                    .lineLimit(1)
            }
        }
    }
}

struct DashboardMetaBadge: View {
    let text: String
    let tint: Color
    let compact: Bool

    init(text: String, tint: Color, compact: Bool = false) {
        self.text = text
        self.tint = tint
        self.compact = compact
    }

    var body: some View {
        Text(text)
            .font((compact ? Font.caption2 : .caption).weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .lineLimit(1)
            .truncationMode(.tail)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 6, style: .continuous))
    }
}

struct DashboardInlinePickerField<Content: View>: View {
    let title: String?
    let width: CGFloat?
    @ViewBuilder var content: Content

    init(
        title: String? = nil,
        width: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.width = width
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardPalette.textSecondary)
            }

            DashboardControlSurface {
                content
            }
        }
        .frame(width: width)
    }
}

struct DashboardSearchField: View {
    let title: String?
    let placeholder: String
    @Binding var text: String

    init(
        title: String? = nil,
        placeholder: String,
        text: Binding<String>
    ) {
        self.title = title
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardPalette.textSecondary)
            }

            DashboardControlSurface {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardPalette.textMuted)

                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder)
                            .foregroundStyle(DashboardPalette.textMuted)
                    )
                        .textFieldStyle(.plain)
                        .foregroundStyle(DashboardPalette.textPrimary)

                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DashboardPalette.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct DashboardIconActionButton: View {
    let systemName: String
    let role: ButtonRole?
    let action: () -> Void

    @State private var isHovering = false

    init(
        systemName: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius, style: .continuous)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 1)
                        )
                }
                .frame(width: DashboardMetrics.minHitArea, height: DashboardMetrics.minHitArea)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if role == .destructive {
            return DashboardPalette.destructive.opacity(isHovering ? 0.14 : 0.08)
        }
        return DashboardPalette.surfaceSecondary.opacity(isHovering ? 1 : 0.74)
    }

    private var borderColor: Color {
        role == .destructive ? DashboardPalette.destructive.opacity(0.18) : DashboardPalette.outlineSoft
    }

    private var foregroundColor: Color {
        role == .destructive ? DashboardPalette.destructive : DashboardPalette.textSecondary
    }
}

struct DashboardPillPicker<Selection: Hashable, Label: View>: View {
    let options: [Selection]
    @Binding var selection: Selection
    let label: (Selection, Bool) -> Label

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option

                Button {
                    selection = option
                } label: {
                    label(option, isSelected)
                        .foregroundStyle(isSelected ? DashboardPalette.textPrimary : DashboardPalette.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: DashboardMetrics.controlHeight)
                        .background {
                            RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius - 1, style: .continuous)
                                .fill(isSelected ? DashboardPalette.surfaceTertiary.opacity(0.48) : Color.clear)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius + 2, style: .continuous)
                .fill(DashboardPalette.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius + 2, style: .continuous)
                        .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
                )
        }
    }
}
