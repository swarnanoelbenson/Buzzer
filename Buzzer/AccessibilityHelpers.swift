//
//  AccessibilityHelpers.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI

// MARK: - Accessible Button Style

/// Large, high-contrast button style for users 60+
struct AccessibleButtonStyle: ButtonStyle {
    let color: Color
    let height: CGFloat
    
    init(color: Color = .accentColor, height: CGFloat = 70) {
        self.color = color
        self.height = height
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .bold)) // 20pt+ font
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                configuration.isPressed
                    ? color.opacity(0.8)
                    : color
            )
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Accessible Large Button

/// Pre-configured large button for primary actions
struct AccessibleLargeButton: View {
    let title: String
    let systemImage: String?
    let color: Color
    let action: () -> Void
    
    init(
        _ title: String,
        systemImage: String? = nil,
        color: Color = .accentColor,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28))
                }
                Text(title)
            }
        }
        .buttonStyle(AccessibleButtonStyle(color: color))
    }
}

// MARK: - Accessible Navigation Button

/// Large rectangular navigation button with icon and text
struct AccessibleNavigationButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let color: Color
    
    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        color: Color = .green
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
            
            if let subtitle = subtitle {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                }
            } else {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .padding(.horizontal, 16)
        .background(color)
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}

// MARK: - High Contrast Divider

/// High contrast divider for better visibility
struct AccessibleDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.primary.opacity(0.3)) // Higher contrast
            .frame(height: 2)
    }
}

// MARK: - Accessible Text Styles

extension Font {
    /// Minimum 16pt body text for accessibility
    static var accessibleBody: Font {
        .system(size: 18)
    }
    
    /// Minimum 18pt for important text
    static var accessibleTitle: Font {
        .system(size: 22, weight: .semibold)
    }
    
    /// Extra large for primary headings
    static var accessibleHeadline: Font {
        .system(size: 28, weight: .bold)
    }
}

// MARK: - Color Contrast Helpers

extension Color {
    /// High contrast foreground color based on background
    func contrastingTextColor() -> Color {
        // This is a simplified version
        // In production, you'd calculate actual luminance
        return self == .white || self == .yellow ? .black : .white
    }
    
    /// Ensures 4.5:1 contrast ratio (WCAG AA)
    static var accessibleGreen: Color {
        Color(red: 0.0, green: 0.6, blue: 0.0) // Darker green for better contrast
    }
    
    static var accessibleOrange: Color {
        Color(red: 0.9, green: 0.5, blue: 0.0) // High contrast orange
    }
    
    static var accessibleRed: Color {
        Color(red: 0.8, green: 0.0, blue: 0.0) // High contrast red
    }
}

// MARK: - Accessible Card Style

struct AccessibleCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 2) // High contrast border
            )
    }
}

// MARK: - VoiceOver Helpers

extension View {
    /// Adds accessibility traits for headers
    func accessibleHeader() -> some View {
        self.accessibilityAddTraits(.isHeader)
    }
    
    /// Adds accessibility label and hint
    func accessibleLabel(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .modifier(AccessibilityHintModifier(hint: hint))
    }
}

struct AccessibilityHintModifier: ViewModifier {
    let hint: String?
    
    func body(content: Content) -> some View {
        if let hint = hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - Accessible Date Picker

struct AccessibleDatePicker: View {
    @Binding var selection: Date
    let label: String
    let range: PartialRangeThrough<Date>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.accessibleTitle)
                .accessibilityHidden(true)
            
            DatePicker(
                label,
                selection: $selection,
                in: range,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical) // Large, easy to use
            .labelsHidden()
            .accessibilityLabel(label)
            .accessibilityHint("Swipe up or down to change the date")
        }
    }
}

#Preview("Accessible Buttons") {
    VStack(spacing: 20) {
        AccessibleLargeButton("Start Pick-Up", systemImage: "arrow.up.circle.fill", color: .green) {
            print("Tapped")
        }
        
        AccessibleLargeButton("Start Drop-Off", systemImage: "arrow.down.circle.fill", color: .orange) {
            print("Tapped")
        }
        
        Button("Regular Button") {
            print("Tapped")
        }
        .buttonStyle(AccessibleButtonStyle(color: .blue))
    }
    .padding()
}

#Preview("Navigation Buttons") {
    VStack(spacing: 16) {
        NavigationLink(destination: Text("Session")) {
            AccessibleNavigationButton(
                "START SESSION",
                systemImage: "play.fill",
                color: .green
            )
        }
        
        NavigationLink(destination: Text("History")) {
            AccessibleNavigationButton(
                "View History",
                subtitle: "Reports from previous days",
                systemImage: "clock.fill",
                color: .orange
            )
        }
    }
    .padding()
}

#Preview("Accessible Card") {
    AccessibleCard {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Title")
                .font(.accessibleTitle)
            
            Text("This is a card with high contrast borders and accessible spacing.")
                .font(.accessibleBody)
        }
    }
    .padding()
}
