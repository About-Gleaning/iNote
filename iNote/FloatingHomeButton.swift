import SwiftUI

enum MenuOption: String, CaseIterable {
    case voiceConsultation = "语音咨询"
    case todaySummary = "今日总结"
    case weeklySummary = "本周总结"
    
    var icon: String {
        switch self {
        case .voiceConsultation: return "mic.fill"
        case .todaySummary: return "sun.max.fill"
        case .weeklySummary: return "calendar"
        }
    }
}

struct FloatingHomeButton: View {
    @AppStorage("floatingButtonX") private var storedX: Double = Double.infinity
    @AppStorage("floatingButtonY") private var storedY: Double = Double.infinity
    @State private var position: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var isExpanded: Bool = false
    
    var onSelect: ((MenuOption) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed Background when expanded
                if isExpanded {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isExpanded = false
                            }
                        }
                        .transition(.opacity)
                }
                
                // Menu Content
                if isExpanded {
                    VStack(spacing: 20) {
                        ForEach(MenuOption.allCases, id: \.self) { option in
                            Button(action: {
                                withAnimation(.spring()) {
                                    isExpanded = false
                                }
                                onSelect?(option)
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 20))
                                        .frame(width: 30)
                                    Text(option.rawValue)
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding()
                                .frame(width: 200)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
                }
                
                // Floating Button
                if !isExpanded {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .position(position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                position = value.location
                            }
                            .onEnded { value in
                                isDragging = false
                                let screenWidth = geometry.size.width
                                let finalX: CGFloat
                                
                                // Snap to nearest edge
                                if value.location.x < screenWidth / 2 {
                                    finalX = 40 // Left edge padding
                                } else {
                                    finalX = screenWidth - 40 // Right edge padding
                                }
                                
                                // Keep Y within bounds
                                let finalY = min(max(value.location.y, 60), geometry.size.height - 60)
                                
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    position = CGPoint(x: finalX, y: finalY)
                                }
                                
                                // Save to AppStorage
                                storedX = finalX
                                storedY = finalY
                            }
                    )
                    .onAppear {
                        if position == .zero {
                            if storedX == Double.infinity {
                                // Default position
                                position = CGPoint(x: geometry.size.width - 40, y: geometry.size.height / 2)
                            } else {
                                position = CGPoint(x: storedX, y: storedY)
                            }
                        }
                    }
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring()) {
                            isExpanded = true
                        }
                    }
                    .zIndex(1)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        FloatingHomeButton(onSelect: { option in
            print("Selected: \(option.rawValue)")
        })
    }
}
