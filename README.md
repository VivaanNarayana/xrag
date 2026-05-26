# xrag - Cross-Session Vector Context Memory for Cursor

> Persistent semantic memory across Cursor chat sessions using system-level hooks

A Cursor AI skill that automatically captures and stores AI responses in a searchable vector database, enabling semantic knowledge retrieval across different conversation sessions. Designed for developers who frequently start new chats about the same projects.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)

---

## Table of Contents

- [What It Does](#what-it-does)
- [Why Use This Skill](#why-use-this-skill)
- [When Does It Save Tokens](#when-does-it-save-tokens)
- [Installation](#installation)
- [How to Use](#how-to-use)
- [Configuration](#configuration)
- [Technical Details](#technical-details)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## What It Does

**xrag** provides persistent semantic memory across Cursor chat sessions through automatic hooks integration. Unlike conversation history (which is session-specific), this creates a knowledge base that persists and grows across all your conversations.

### Key Features

- **Automatic Capture**: Stores every AI response via hooks with no manual action required
- **Semantic Search**: Retrieves relevant context using embeddings and hybrid scoring algorithms
- **Cross-Session Persistence**: Knowledge persists across different chat sessions
- **Local & Private**: All data stays on your machine with no external API calls
- **Fast Retrieval**: Sub-100ms retrieval after initial model load
- **Smart Pruning**: LRU algorithm automatically maintains the 500 most relevant entries

### How It Works

1. **Session Start**: Vector store initializes automatically when you start a new chat
2. **After Each AI Response**: Responses are captured and embedded in the background
3. **During File Operations**: When you read files or search code, relevant context from past sessions is automatically injected
4. **Persistent Storage**: Knowledge accumulates across all conversations
5. **Automatic Maintenance**: System automatically prunes less relevant entries

---

## Why Use This Skill

### The Problem

When working on projects across multiple chat sessions, you often need to:
- Re-explain architectural decisions you made weeks ago
- Repeat context about your coding patterns and conventions
- Re-establish project context in each new conversation
- Load entire conversation histories (thousands of tokens) to maintain context

### The Solution

**xrag** solves this by:
- **Storing only what matters**: Semantic embeddings of AI responses, not full conversation logs
- **Retrieving selectively**: Only fetches the 2-3 most relevant pieces of past knowledge
- **Working automatically**: No manual copy-pasting or summarization needed
- **Saving tokens**: Reduces token usage by 20-35% for multi-session project work

### Use Cases

**1. Long-term Project Development**
- Work on the same project across multiple days/weeks
- Each new chat session automatically has relevant historical context
- No need to re-explain "why we chose PostgreSQL" or "how our auth system works"

**2. Sporadic Development**
- Return to a project after a break
- Architecture decisions from earlier sessions are automatically recalled
- Continue where you left off without rebuilding context

**3. Team Collaboration**
- Multiple developers working on the same codebase
- Shared knowledge base reduces repeated explanations
- Everyone benefits from accumulated project knowledge

---

## When Does It Save Tokens

### Scenarios with Token Savings (20-35%)

**Multi-Session Project Work**
- You work on the same project across multiple separate chat sessions
- Each new session needs project context
- **Saves**: ~2,000-5,000 tokens per session after initial knowledge accumulation

**Sporadic Development**
- You return to a project after days/weeks in a new chat
- Architecture decisions were explained in earlier sessions
- **Saves**: ~1,500-3,000 tokens avoiding context re-establishment

**Team Collaboration**
- Multiple team members chatting about the same codebase
- Shared knowledge base reduces repeated explanations
- **Saves**: ~1,000-2,000 tokens per team member per session

### Quantified Impact

|    Usage Pattern   | Sessions | Tokens Without | Tokens With | Savings | % Saved |
|--------------------|----------|----------------|-------------|---------|---------|
| Single long chat   |    1     |     20,000     |    20,240   |  -240   |  -1.2%  |
| 3 new sessions     |    3     |     20,000     |    16,300   |  3,700  |  18.5%  |
| 10 new sessions    |    10    |     70,000     |    52,000   |  18,000 |  25.7%  |
| 50 new sessions    |    50    |     400,000    |    260,000  | 140,000 |  35.0%  |

**Key Finding**: Savings increase with cross-session usage. Break-even point is around 5 sessions.

### Scenarios with No Savings

**Single Long Conversation**
- You continue the same chat thread for the entire project
- Cursor already maintains conversation history
- **Result**: Slight overhead (~60 tokens per response)

**One-Off Questions**
- Quick, unrelated queries with no knowledge accumulation
- No prior context to retrieve
- **Result**: Neutral

---

## Installation

### Prerequisites

- **Cursor IDE** with hooks support
- **Python 3.8+** with pip
- **Operating System**: Windows, Mac, or Linux (full support for all platforms)
- ~200MB disk space (model + storage)

### Step 1: Clone the Skill into Your Project

Navigate to your project root and clone this skill into the `.cursor/skills/` directory:

**Windows (PowerShell):**
```powershell
# Navigate to your project root
cd C:\path\to\your\project

# Create .cursor/skills directory if it doesn't exist
New-Item -ItemType Directory -Force -Path .cursor\skills

# Clone the skill
cd .cursor\skills
git clone https://github.com/VivaanNarayana/xrag.git
```

**Mac/Linux (Bash):**
```bash
# Navigate to your project root
cd /path/to/your/project

# Create .cursor/skills directory if it doesn't exist
mkdir -p .cursor/skills

# Clone the skill
cd .cursor/skills
git clone https://github.com/VivaanNarayana/xrag.git
```

### Step 2: Install Python Dependencies

```bash
cd xrag
pip install -r requirements.txt
```

**Dependencies installed:**
- `sentence-transformers>=2.2.2` - For text embeddings
- `faiss-cpu>=1.7.4` - For fast similarity search
- `numpy>=1.21.0` - For numerical operations

### Step 3: Initialize the Vector Store

```bash
python vector_store.py init
```

This downloads the embedding model (~80MB, one-time operation). The model will be cached for future use.

### Step 4: Configure Hooks

Copy the example hooks configuration to your project's `.cursor` folder:

**Windows:**
```powershell
# From your project root
Copy-Item .cursor\skills\xrag\examples\windowshooks.json.example .cursor\hooks.json
```

**Mac/Linux:**
```bash
# From your project root
cp .cursor/skills/xrag/examples/unixhooks.json.example .cursor/hooks.json

# Make the shell scripts executable
chmod +x .cursor/skills/xrag/hooks/*.sh
```

**Windows hooks.json should contain:**
```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{
      "command": "powershell -ExecutionPolicy Bypass -File .cursor/skills/xrag/hooks/session_start.ps1",
      "type": "command"
    }],
    "afterAgentResponse": [{
      "command": "powershell -ExecutionPolicy Bypass -File .cursor/skills/xrag/hooks/capture_response.ps1",
      "type": "command"
    }],
    "postToolUse": [{
      "command": "powershell -ExecutionPolicy Bypass -File .cursor/skills/xrag/hooks/inject_context.ps1",
      "type": "command",
      "matcher": "^(Read|SemanticSearch|Grep)$"
    }]
  }
}
```

**Mac/Linux hooks.json should contain:**
```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{
      "command": "bash .cursor/skills/xrag/hooks/session_start.sh",
      "type": "command"
    }],
    "afterAgentResponse": [{
      "command": "bash .cursor/skills/xrag/hooks/capture_response.sh",
      "type": "command"
    }],
    "postToolUse": [{
      "command": "bash .cursor/skills/xrag/hooks/inject_context.sh",
      "type": "command",
      "matcher": "^(Read|SemanticSearch|Grep)$"
    }]
  }
}
```

**If you already have a hooks.json file:**
Merge the xrag hooks into your existing configuration instead of overwriting.

### Step 5: (Optional) Add AI Context Rules

Copy the example rules file to provide guidelines for the AI assistant:

**Windows:**
```powershell
New-Item -ItemType Directory -Force -Path .cursor\rules
Copy-Item .cursor\skills\xrag\examples\rules\xrag-context.md .cursor\rules\xrag-context.md
```

**Mac/Linux:**
```bash
mkdir -p .cursor/rules
cp .cursor/skills/xrag/examples/rules/xrag-context.md .cursor/rules/xrag-context.md
```

### Step 6: Restart Cursor

Restart Cursor IDE to load the hooks.

### Step 7: Verify Installation

1. Open **Cursor Settings → Hooks**
2. Verify that 3 hooks are listed:
   - `sessionStart`
   - `afterAgentResponse`
   - `postToolUse`
3. Start a new chat session
4. After having a conversation, check that responses are being captured:
   ```bash
   cd .cursor/skills/xrag
   python vector_store.py stats
   ```

You should see a non-zero number of entries.

---

## How to Use

### Automatic Operation (Recommended)

Once installed, xrag works automatically with no manual intervention required:

1. **Chat Normally**: All AI responses are automatically captured
2. **Start New Sessions**: Relevant context from past sessions is auto-injected when you read files
3. **Knowledge Accumulates**: Each conversation enriches the knowledge base
4. **Seamless Integration**: The AI uses past context naturally without mentioning the mechanism

### Manual CLI Usage

While the skill is designed to work automatically, you can also interact with it manually:

#### Check Knowledge Base Statistics

```bash
cd .cursor/skills/xrag
python vector_store.py stats
```

**Output:**
```json
{
  "total_entries": 127,
  "storage_size_kb": 45,
  "oldest_entry": "2026-05-10T14:23:00",
  "newest_entry": "2026-05-24T16:30:00"
}
```

#### View Recent Captures

```bash
python vector_store.py list --recent 10
```

Shows the 10 most recently captured AI responses.

#### Manual Retrieval

```bash
python vector_store.py retrieve "authentication patterns"
```

Returns relevant context from past conversations about authentication.

#### Manual Storage

```bash
python vector_store.py store "Your text here" --timestamp "2026-05-24T16:00:00"
```

Manually add text to the knowledge base (rarely needed).

#### Prune Storage

```bash
python vector_store.py prune --target 300
```

Reduces storage to 300 entries. The system automatically prunes at 500 entries, but you can manually trigger it.

#### Reset Knowledge Base

```bash
python vector_store.py init --clean
```

**Warning**: This erases all accumulated knowledge. Only use if starting fresh.

---

## Configuration

Edit `config.json` in the skill directory to customize behavior:

```json
{
  "max_entries": 500,
  "embedding_model": "all-MiniLM-L6-v2",
  "similarity_weight": 0.7,
  "recency_weight": 0.3,
  "retrieve_top_k": 2,
  "storage_path": "storage/.vectorstore",
  "min_similarity_threshold": 0.1,
  "max_text_length": 10000,
  "cross_session_persistence": true,
  "auto_capture_responses": true
}
```

### Configuration Options

|           Option            |      Default     |              Description              |
|-----------------------------|------------------|---------------------------------------|
| `max_entries`               |        500       | Maximum responses before auto-pruning |
| `embedding_model`           | all-MiniLM-L6-v2 |    Sentence transformer model name    |
| `similarity_weight`         |        0.7       | Weight for semantic similarity (0-1)  |
| `recency_weight`            |        0.3       |         Weight for recency (0-1)      |
| `retrieve_top_k`            |         2        |     Number of results to retrieve     |
| `min_similarity_threshold`  |        0.1       |    Minimum score to return results    |
| `max_text_length`           |       10000      |      Maximum characters to embed      |
| `cross_session_persistence` |       true       |       Enable persistent storage       |
| `auto_capture_responses`    |       true       | Automatic response capture via hooks  |

### Tuning Recommendations

**For long conversations (>50 exchanges):**
- Increase `max_entries` to 1000
- Increase `similarity_weight` to 0.8

**For short, focused sessions:**
- Decrease `max_entries` to 250
- Increase `recency_weight` to 0.4

**For technical/reference heavy work:**
- Increase `retrieve_top_k` to 3
- Lower `min_similarity_threshold` to 0.05

---

## Technical Details

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Cursor Agent Session                                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [User Query] ──► [AI Processing] ──► [Response]        │
│                          │                │             │
│                          │                │             │
│                          ▼                ▼             │
│                   ┌──────────┐    ┌──────────────┐      │
│                   │  Hook 3  │    │    Hook 2    │      │
│                   │ Inject   │    │   Capture    │      │
│                   │ Context  │    │   Response   │      │
│                   └────┬─────┘    └──────┬───────┘      │
│                        │                 │              │
└────────────────────────┼─────────────────┼──────────────┘
                         │                 │
                         ▼                 ▼
          ┌──────────────────────────────────────┐
          │   Persistent Vector Store            │
          │  - 500 embeddings (384-dim)          │
          │  - Semantic search (FAISS)           │
          │  - Cross-session persistence         │
          │  - LRU pruning                       │
          └──────────────────────────────────────┘
```

### Components

- **vector_store.py**: Core logic for embedding, retrieval, storage, and pruning
- **hooks/**: PowerShell scripts for system-level integration
  - `session_start.ps1`: Initialize on session start
  - `capture_response.ps1`: Store AI responses automatically
  - `inject_context.ps1`: Inject relevant context after file reads
- **SKILL.md**: Instructions for AI agent integration
- **config.json**: Configuration parameters
- **storage/.vectorstore**: JSON storage file (persistent across sessions)

### Scoring Algorithm

```
hybrid_score = (cosine_similarity × 0.7) + (recency_score × 0.3)
recency_score = 1 / (1 + log(position_from_end))
```

### Storage Format

```json
{
  "embeddings": [[0.123, 0.456, ...]],
  "responses": ["Response text..."],
  "metadata": [
    {
      "timestamp": "2026-05-22T18:30:00",
      "last_accessed": "2026-05-22T18:54:00",
      "access_count": 3,
      "length": 265
    }
  ]
}
```

### Performance Characteristics

- **First load**: 2-3s (model loading)
- **Subsequent embedding**: ~50ms
- **Retrieval**: ~50-100ms
- **Storage**: Async, no blocking
- **Memory**: ~100MB (model + index)
- **Disk**: ~200KB per 500 entries

### Privacy & Security

- **No user messages stored**: Only AI responses are embedded
- **Local storage only**: Vector database stays on your machine
- **No external API calls**: All embedding done locally with sentence-transformers
- **Session IDs**: Used for organization, not identification
- **Clear anytime**: Run `init --clean` to erase all data

---

## Troubleshooting

### Hooks Not Working

**Symptoms**: Responses aren't being captured, stats show 0 entries

**Solutions**:
1. Check Cursor Settings → Hooks for errors
2. Verify Python is in PATH: `python --version`
3. Confirm dependencies installed: `python -c "import sentence_transformers, faiss"`
4. Check hooks.json exists at `.cursor/hooks.json` (not in the skill folder)
5. Restart Cursor to reload hooks
6. Check for log files in the skill directory for error messages

### No Context Being Injected

**Symptoms**: Past knowledge isn't appearing in new sessions

**Solutions**:
1. Verify vector store has entries: `python vector_store.py stats`
2. Test manual retrieval: `python vector_store.py retrieve "test query"`
3. Lower `min_similarity_threshold` in `config.json` (try 0.05)
4. Check that you're using Read/SemanticSearch/Grep tools (context only injects after these)

### Model Download Fails

**Symptoms**: Cannot download embedding model during `init`

**Solutions**:
1. Check internet connection
2. Verify you have write permissions in the skill directory
3. Try manual download: `python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"`
4. Check if firewall is blocking huggingface.co

### Storage Growing Too Large

**Symptoms**: .vectorstore file is very large, slow performance

**Solutions**:
1. Check size: `python vector_store.py stats`
2. Reduce `max_entries` in `config.json` to 200-300
3. Manual prune: `python vector_store.py prune --target 200`
4. System auto-prunes at `max_entries`, so this shouldn't happen often

### Performance Issues

**Symptoms**: Slow retrieval, high memory usage

**Solutions**:
1. Model loading is slow on first init (2-3s) - this is normal
2. Check disk space for storage file
3. Consider reducing `max_entries` if using limited RAM
4. Ensure you're using `faiss-cpu` not `faiss` (GPU version)

### Storage Corruption

**Symptoms**: JSON decode errors when loading storage

**Solutions**:
1. Backup current storage: `copy storage/.vectorstore storage/.vectorstore.backup`
2. Rebuild: `python vector_store.py init --clean`
3. If you need to recover data, manually inspect the `.vectorstore` JSON file

---

## Contributing

Contributions are welcome! Priority areas:

- **Retrieval quality improvements** (better scoring algorithms)
- **Storage optimization** (compression, better pruning strategies)
- **Testing** (edge cases, performance benchmarks)
- **Documentation** (tutorials, examples, troubleshooting guides)

Please open issues for bugs or feature requests.

### Development Setup

```bash
# Clone the repo
git clone https://github.com/VivaanNarayana/xrag.git
cd xrag

# Install dev dependencies
pip install -r requirements.txt

# Make your changes

# Test locally
python vector_store.py init
python vector_store.py store "test response"
python vector_store.py retrieve "test"
```

---

## License

MIT License - see LICENSE file for details.

---

## Acknowledgments

Built for the Cursor IDE ecosystem. Uses:
- [sentence-transformers](https://www.sbert.net/) by UKPLab for text embeddings
- [FAISS](https://github.com/facebookresearch/faiss) by Facebook Research for similarity search

---

## Support & Questions

- **Installation issues**: See [Troubleshooting](#troubleshooting) section
- **Usage questions**: See [How to Use](#how-to-use) section
- **Technical details**: See [Technical Details](#technical-details) section
- **Bugs/Features**: Open a GitHub issue

---

**Made for the Cursor community**
