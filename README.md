## About

This repository introduces **Retrieval-Augmented Generation (RAG)**
using the [llm.rb](https://github.com/llmrb/llm) library. <br> The example
is only 27-lines of Ruby code 🫡

## Context

For storage and retrieval, we’ll use [OpenAI’s Vector Stores API]()
as our vector database. If "RAG" or “vector database” are new terms
for you, don’t worry &ndash; we’ll cover them both briefly before
diving into the example. Our "knowledge base" or primary content
will be composed of the files found in the
[documents/](documents/)
directory, and it contains the FreeBSD handbook &ndash;
with one file per chapter.


## Background

### What is RAG?

RAG is a technique whereby a language model is given
extra context &ndash; retrieved from an external knowledge
source &ndash; before generating a response.

With RAG, you supply your own knowledge base at query time.
The LLM then generates responses **based entirely (or primarily)
on that provided context**, ensuring the answers are grounded in your
chosen source of truth.

For example, an engineering team could load the company’s internal
API docs into a RAG system. Queries about those APIs would return
accurate, up-to-date answers, even if the model was trained long
before those APIs existed.

### What is a vector database?

A vector database is a common choice for storing and retrieving
the context used in RAG. We will be dealing with a text-based vector
database but it is worth knowing that vector databases can also
handle images, audio, and other types of data.

Here’s the basic idea:
- **Embeddings**: Text is converted into a high-dimensional numeric
                  representation (an “embedding”) that captures
                  semantic meaning.
- **Search**: Given a query, the database compares embeddings to
              find the most semantically similar text chunks.
- **Results**: The most relevant chunks are returned and injected
               into the LLM’s prompt.

In RAG, these retrieved chunks form the knowledge base for that
particular prompt. The LLM can then use them to answer questions,
summarize, or otherwise respond with grounding in specific,
relevant information.

## Example

### Explanation

The following example adds the contents of the [docments/](documents/)
directory by uploading them as files via OpenAI's Files API. The next
step is to create a vector store, and the vector store will be composed
of the files that we just uploaded.

After the vector store is created, and it is ready, we can search the
vector store with a query. The query will produce one or more chunks of
text, and those chunks will be provided to the [system prompt](prompts/system.erb.txt).

Finally, the bot will generate a response based on the system prompt
and the user’s question. This is done in an infinite loop, so you can
ask as many questions as you like, and the bot will respond with
answers based on the context provided by the vector store.

```ruby
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
```