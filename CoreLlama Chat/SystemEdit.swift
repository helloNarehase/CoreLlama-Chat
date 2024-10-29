import SwiftUI

struct SystemEdit: View {
    var title: String
    var edit: String
    @Binding var bind_edit: String
    
    
    @State private var singleLineText: String = ""
    
    
    var body: some View {
        VStack {
            // 1줄 텍스트 에디트
            TextField(title, text: $singleLineText)
                .padding()
                .background(Color.gray.opacity(0.2)) // 배경 색과 투명도 설정
                .cornerRadius(10) // 모서리 둥글게
                .padding()
                .frame(maxWidth: .infinity)
            
            VStack {
                Text(edit)
                // 여러 줄 텍스트 에디트
                TextEditor(text: $bind_edit)
                    .cornerRadius(10) // 모서리 둥글게
                    .frame(height: 200) // 원하는 높이 설정 가능
                    .frame(maxWidth: .infinity)
                    .shadow(radius: 1)
            }
            .padding()
            // Done 버튼
            Button(action: {
                // 버튼 클릭 시 실행할 동작
                print("Done 버튼 클릭!")
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10) // 모서리 둥글게
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
//#Preview {
//    SystemEdit(title:"Hello, World!", edit: "hello just edit")
//}
