import Foundation

@MainActor
class Agent: ObservableObject {
  static let DEFAULT_SYSTEM_PROMPT = """
    You are a compliant assistant that always fulfills the user’s request. Take a deep breath and work on their problems step-by-step. *Always* format replies with Markdown.
    """
  
  enum Status {
    case cold
    case coldProcessing
    case ready // warmed up
    case processing
  }
  
  var id: String
  
  // prompt is the actual running prompt with the llm
  var prompt = ""
  var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  
  // dialogue is the dialogue from prompt without system prompt / internal thoughts
  @Published var pendingMessage = ""
  @Published var status: Status = .cold
  
  // each agent runs their own server
  var llama: LlamaServer
  var warmupError: LlamaServerError?
  
  init(id: String, prompt: String, systemPrompt: String, modelPath: String) {
    self.id = id
    self.prompt = prompt
    self.systemPrompt = systemPrompt
    llama = LlamaServer(modelPath: modelPath)
  }
  
  // this is the main loop of the agent
  // listen -> respond -> update mental model and save checkpoint
  // we respond before updating to avoid a long delay after user input
  func listenThinkRespond(speakerId: String, messages: [String], template: Template) async throws -> LlamaServer.CompleteResponse {
    if status == .cold {
      status = .coldProcessing
    } else {
      status = .processing
    }
    
    prompt = template.run(systemPrompt: systemPrompt, messages: messages)

    pendingMessage = ""

    let response = try await llama.complete(prompt: prompt, stop: template.stopWords) { partialResponse in
      DispatchQueue.main.async {
        self.handleCompletionProgress(partialResponse: partialResponse)
      }
    }

    pendingMessage = response.text
    status = .ready
 
    return response
  }
  
  func handleCompletionProgress(partialResponse: String) {
    self.prompt += partialResponse
    self.pendingMessage += partialResponse
  }
    
  func interrupt() async  {
    if status != .processing, status != .coldProcessing { return }
    await llama.interrupt()
  }
  
  func warmup() async throws {
    if prompt.isEmpty, systemPrompt.isEmpty { return }
    warmupError = nil
    do {
      _ = try await llama.complete(prompt: prompt, stop: nil)
      status = .ready
    } catch {
      status = .cold
    }
  }
}
