---
name: xrag
description: Maintains persistent cross-session vector storage of AI responses for semantic knowledge retrieval across conversations. Automatically embeds and stores AI responses via hooks, enabling semantic search of knowledge from past sessions without keeping full conversation histories. Use for knowledge retention, reference retrieval, and learning from previous conversations across different chat sessions.
---

# Cross-Session Vector Context Memory

This skill provides **persistent semantic memory across Cursor chat sessions** through system-level hooks integration. Unlike conversation history (which is session-specific), this creates a knowledge base that persists and grows across all your conversations.

## How It Works (System-Level Integration)

This skill operates **automatically via Cursor hooks** - no manual intervention needed:

1. **Session Start**: Vector store initializes automatically
2. **After Each AI Response**: Responses are captured and embedded in background
3. **During File Reads/Searches**: Relevant context from past sessions is automatically injected
4. **Persistent Storage**: Knowledge accumulates across all conversations
5. **Automatic Pruning**: Maintains 500 most relevant entries using LRU

## Value Proposition

**Saves tokens by enabling knowledge reuse across sessions without loading full conversation histories.**

### Example Scenarios:

**Scenario 1 - Architecture Decisions**:
- *Session 1*: You discuss why you chose PostgreSQL over MongoDB for your project
- *Session 2* (days later): You ask about database optimization
- *Result*: The system automatically recalls the PostgreSQL choice context

**Scenario 2 - Code Patterns**:
- *Session 1*: AI explains your custom error handling pattern
- *Session 3* (new conversation): You work on a new feature
- *Result*: Error handling context is automatically available without re-explaining

**Scenario 3 - Project Knowledge**:
- Multiple conversations about different features accumulate
- Any new conversation can semantically retrieve relevant past discussions
- No need to summarize or re-explain project context

## Installation

### One-Time Setup

1. **Install dependencies**:
```bash
cd .cursor/skills/xrag
pip install -r requirements.txt
```

2. **Initialize the vector store**:
```bash
python vector_store.py init
```

This downloads the embedding model (80MB, one-time).

3. **Verify hooks are loaded**:
- Open Cursor Settings → Hooks
- Check that 3 hooks are registered for this skill
- Hooks will auto-activate on next session start

## How Hooks Work

### Hook 1: Session Start
- **Trigger**: Beginning of each agent session
- **Action**: Ensures vector store is initialized
- **Fails**: Silently (won't block session if unavailable)

### Hook 2: Capture Responses  
- **Trigger**: After each AI response in conversation
- **Action**: Embeds and stores response in background
- **Filters**: Skips responses shorter than 50 characters
- **Performance**: Async - doesn't block conversation flow

### Hook 3: Inject Context
- **Trigger**: After `Read`, `SemanticSearch`, or `Grep` tool usage
- **Action**: Retrieves and injects relevant context from past sessions
- **Threshold**: Only injects if relevance score > 0.6
- **Format**: Clearly marked as "context from past sessions"

## Automatic vs Manual Usage

### Automatic (Recommended)
Once installed, hooks handle everything automatically. The AI will:
- See relevant context from past sessions when reading files
- Build a persistent knowledge base across conversations
- Never mention the mechanism to you (seamless integration)

### Manual Retrieval
You can manually query the knowledge base:

```bash
python .cursor/skills/xrag/vector_store.py retrieve "your question"
```

Useful for:
- Checking what the system remembers
- Debugging retrieval quality
- Manual knowledge lookups

## Configuration

Settings in `config.json`:
- **max_entries**: 500 responses (cross-session storage)
- **retrieve_top_k**: 2 most relevant results
- **similarity_weight**: 0.7 (semantic relevance)
- **recency_weight**: 0.3 (temporal proximity)
- **cross_session_persistence**: true (knowledge persists across chats)
- **auto_capture_responses**: true (automatic via hooks)

## Token Savings Mechanism

### How This Saves Tokens:

**Traditional Approach**:
- Load full conversation history (10,000+ tokens)
- Re-explain project decisions in each new chat
- Repeat context across sessions

**With Cross-Session Memory**:
- Only retrieve 2 most relevant past insights (~500 tokens)
- Knowledge accumulates without repeated explanations
- New sessions start with relevant context, not full history

**Example Token Savings**:
- Session 1: 5,000 tokens (establishing context)
- Session 2 without skill: 5,000 tokens + 5,000 history = 10,000 tokens
- Session 2 with skill: 5,000 tokens + 500 retrieved = 5,500 tokens
- **Savings: ~4,500 tokens (45% reduction)**

### Best Practices for Maximum Savings

1. **Let knowledge accumulate**: The more conversations, the more valuable the knowledge base
2. **Start fresh sessions**: New chat for new topics maximizes savings
3. **Trust the retrieval**: Don't re-explain what's in the knowledge base
4. **Review periodically**: Check what's stored with `stats` command

## Performance Characteristics

- **First session**: 2-3s initial model load
- **Subsequent loads**: <100ms per retrieval
- **Storage**: Async, no blocking
- **Memory**: ~100MB (model + index)
- **Disk**: ~200KB per 500 entries

## Monitoring & Maintenance

### Check Knowledge Base Stats
```bash
cd .cursor/skills/xrag
python vector_store.py stats
```

Output:
- Total stored responses
- Storage size on disk
- Oldest/newest entries
- Average response length

### View Recent Captures
```bash
python vector_store.py list --recent 10
```

Shows the 10 most recently captured AI responses.

### Manual Pruning
```bash
python vector_store.py prune --target 300
```

Reduces storage to 300 entries (automatic at 500 by default).

### Clear All Knowledge
```bash
python vector_store.py init --clean
```

⚠️ **Warning**: This erases all accumulated knowledge. Only use if starting fresh.

## Troubleshooting

### Hooks Not Working
1. Check Cursor Settings → Hooks for errors
2. Verify Python is in PATH: `python --version`
3. Confirm dependencies: `python -c "import sentence_transformers, faiss"`
4. Restart Cursor to reload hooks

### No Context Being Injected
1. Check if vector store has entries: `python vector_store.py stats`
2. Test manual retrieval: `python vector_store.py retrieve "test query"`
3. Verify similarity threshold in `config.json` (lower if needed)

### Storage Growing Too Large
1. Check size: `python vector_store.py stats`
2. Reduce `max_entries` in `config.json` to 200-300
3. Manual prune: `python vector_store.py prune --target 200`

### Performance Issues
1. Model loading slow on first init (normal, 2-3s)
2. Check disk space for storage file
3. Consider reducing `max_entries` if using limited RAM

## What Gets Stored

**Stored**:
- AI responses longer than 50 characters
- Responses with substantive technical content
- All conversations across sessions

**Not Stored**:
- User messages (privacy)
- Very short responses (< 50 chars)
- System messages

**Metadata Captured**:
- Timestamp
- Session ID
- Response length
- Last accessed time
- Access count (for LRU pruning)

## Privacy & Security

- **No user messages stored**: Only AI responses are embedded
- **Local storage only**: Vector database stays on your machine
- **No external API calls**: All embedding done locally
- **Session IDs**: Used for organization, not identification
- **Clear anytime**: Run `init --clean` to erase all data

## Advanced Usage

### Manual Context Injection
```bash
# Retrieve and format for use
python vector_store.py retrieve "your query" --top-k 3
```

### Batch Operations
```bash
# Store multiple responses from a file
cat responses.txt | while read line; do
  python vector_store.py store "$line"
done
```

### Integration with Other Tools
The vector store can be queried by any script or tool:
```python
from vector_store import VectorStore

store = VectorStore()
results = store.retrieve("authentication patterns", top_k=2)
for result in results:
    print(f"Score: {result['score']}")
    print(f"Text: {result['text']}")
```
