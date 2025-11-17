import SwiftUI

struct NewLeftPanelView: View {
    @Binding var current: Int
    /// 点击 Begin 时要执行的动作，由外部注入
    let onBegin: () -> Void
    
    /// 点击 Next step 时要执行的动作，由外部注入
    let onNext: () -> Void
    
    var body: some View {
        VStack {
            Text("Step \(current)")
                .font(.title)
                .foregroundColor(.white)
                .padding(.bottom, 4)
            Button("Begin") {
                onBegin()
            }
            .padding()
            .buttonStyle(.borderedProminent)
            
            Button("Next step") {
                onNext()
            }
            .padding()
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(Color.black.opacity(0.2))
    }
}
