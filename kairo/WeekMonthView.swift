import SwiftUI

struct WeekMonthView: View {
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var selectedDate = Date()
    
    enum TimeFrame {
        case week, month
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header with toggle
                VStack(spacing: 20) {
                    Text("Cosmic Forecast")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                    
                    // Week/Month Toggle
                    HStack(spacing: 0) {
                        ForEach([TimeFrame.week, TimeFrame.month], id: \.self) { timeframe in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTimeframe = timeframe
                                }
                            }) {
                                Text(timeframe == .week ? "Week" : "Month")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTimeframe == timeframe ? .black : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedTimeframe == timeframe ?
                                        Capsule().fill(Color.white) :
                                        Capsule().fill(Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(4)
                    .background(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 200)
                }
                .padding(.top, 20)
                
                if selectedTimeframe == .week {
                    WeekView()
                } else {
                    MonthView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.black)
    }
}

struct WeekView: View {
    let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    @State private var selectedDay = 3 // Thursday
    
    var body: some View {
        VStack(spacing: 24) {
            // Day selector
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    VStack(spacing: 8) {
                        Text(weekDays[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Circle()
                            .fill(selectedDay == index ? Color.white : Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("\(15 + index)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedDay == index ? .black : .white.opacity(0.6))
                            )
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDay = index
                        }
                    }
                }
            }
            
            // Daily insight
            AstroCard {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Thursday's Energy", systemImage: "waveform")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Venus enters your house of transformation. Deep connections await, but only if you're willing to be vulnerable. The cosmos rewards authenticity today.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(6)
                }
            }
            
            // Week themes
            VStack(alignment: .leading, spacing: 16) {
                Text("This Week's Themes")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                ForEach(["Release old patterns", "Embrace new beginnings", "Trust your intuition"], id: \.self) { theme in
                    HStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                        
                        Text(theme)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MonthView: View {
    let calendar = Calendar.current
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack(spacing: 24) {
            // Month header
            HStack {
                Text("January 2025")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                ForEach(1..<32) { day in
                    Text("\(day)")
                        .font(.system(size: 14))
                        .foregroundColor(day == 15 ? .black : .white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(day == 15 ? Color.white : Color.white.opacity(0.05))
                        )
                }
            }
            
            // Monthly overview
            AstroCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("January Overview")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text("A month of new beginnings. Jupiter's influence brings expansion and opportunity. Stay grounded as you reach for the stars.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(6)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Lucky Days")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Text("7, 15, 23")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Challenge Days")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Text("11, 19, 28")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    WeekMonthView()
}