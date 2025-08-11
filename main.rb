require "llm"
require "erb"

llm   = LLM.openai(key: ENV["OPENAI_SECRET"])
bot   = LLM::Bot.new(llm)
docs  = Dir["documents/*.pdf"]
files = docs.map { llm.files.create(file: _1) }
store = llm.vector_stores.create(name: "FreeBSD Handbook", file_ids: files.map(&:id))

while store.status != "completed"
  sleep(0.5)
  store = llm.vector_stores.get(vector: store)
end

loop do
  print "> "
  question = $stdin.gets.chomp
  res = llm.vector_stores.search(vector: store, query: question)
  chunks = res.data.select { _1.score > 0.7 }
  bot.chat(stream: $stdout) do |prompt|
    prompt.system ERB.new(File.read("prompts/system.erb.txt")).result(binding)
    prompt.user(question)
  end.to_a
  print "\n"
rescue LLM::Error => e
  print e.class.to_s + ": " + e.message + "\n"
end