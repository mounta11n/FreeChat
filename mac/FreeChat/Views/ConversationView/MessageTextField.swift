//
//  MessageTextField.swift
//  Chats
//
//  Created by Peter Sugihara on 8/5/23.
//

import SwiftUI

struct ChatStyle: TextFieldStyle {
  @Environment(\.colorScheme) var colorScheme
  var focused: Bool
  let cornerRadius = 16.0
  var rect: RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
  }
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .textFieldStyle(.plain)
      .frame(maxWidth: .infinity)
      .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
      .padding(8)
      .cornerRadius(cornerRadius)
      .overlay( // regular border
        rect.stroke(Color.primary.opacity(0.2), lineWidth: 1)
      )
      .overlay( // focus ring
        rect
          .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
          .scaleEffect(focused ? 1 : 1.02)
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0.5)
          .opacity(focused ? 1 : 0)
      )
      .animation(focused ? .easeIn(duration: 0.2) : .easeOut(duration: 0.0), value: focused)
  }
}

struct MessageTextField: View {
  @State var input: String = ""
  
  @EnvironmentObject var conversationManager: ConversationManager
  var conversation: Conversation {  conversationManager.currentConversation }

  var onSubmit: (String) -> Void
  @State var showNullState = false
  
  @FocusState private var focused: Bool
  
  var nullState: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(QuickPromptButton.quickPrompts) { p in
          QuickPromptButton(input: $input, prompt: p)
        }
      }.padding(.horizontal, 10).padding(.top, 200)
      
    }.frame(maxWidth: .infinity)
  }
  
  var inputField: some View {
    Group {
      TextField("Message (⌥ + ⏎ for new line)", text: $input, axis: .vertical)
        .onSubmit {
          if CGKeyCode.kVK_Shift.isPressed {
            input += "\n"
          } else if input.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            onSubmit(input)
            input = ""
          }
        }
        .focused($focused)
        .textFieldStyle(ChatStyle(focused: focused))
        .submitLabel(.send)
        .padding(.all, 10)
        .onAppear {
          self.focused = true
        }
        .onChange(of: conversation) { nextConversation in
          if conversationManager.showConversation() {
            self.focused = true
            QuickPromptButton.quickPrompts.shuffle()
          }
        }
        .background(.thinMaterial)
    }
  }
  
  
  var body: some View {
    let messages = conversation.messages
    let showNullState = input == "" && (messages == nil || messages!.count == 0)
    
    VStack(alignment: .trailing) {
      if showNullState {
        nullState.transition(.asymmetric(insertion: .push(from: .trailing), removal: .identity))
      }
      inputField
    }
  }
}



//#if DEBUG
//struct MessageTextField_Previews: PreviewProvider {
//  static var previews: some View {
//    MessageTextField(conversation: c, onSubmit: { _ in print("submit") })
//      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//  }
//}
//#endif
