//
//  WelcomeView.swift
//  W Reminder
//
//  Created for Guest Mode
//

import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea() // Deep background
            
            VStack(spacing: 30) {
                Spacer()
                
                // Hero Image or Icon
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(Color(hex: "5D5FEF")) // Modern Blurple
                    .shadow(color: Color(hex: "5D5FEF").opacity(0.5), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 12) {
                    Text("Welcome to\nW Reminder")
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    
                    Text("Simple, fast, and synced across your devices.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button {
                    onGetStarted()
                } label: {
                    Text("Get Started")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "5D5FEF"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "5D5FEF").opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
    }
}
