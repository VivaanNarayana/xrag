---
name: Cross-Session Context Retrieval
description: Automatically retrieves relevant knowledge from past AI conversations at session start
triggers:
  - session_start
  - new_conversation
---

# Context Continuity

When relevant context from previous conversations exists, it will be available to maintain continuity across sessions. This happens automatically in the background.

## How It Works

The assistant has access to relevant knowledge from past interactions when it helps improve understanding of:
- Project architecture and design decisions
- Coding patterns and conventions you've established
- Previous discussions about technical approaches
- Context about ongoing work

## Context Integration

Context is seamlessly integrated when relevant. The assistant will:
- Reference previous decisions naturally when they apply
- Maintain consistency with established patterns
- Continue conversations across sessions without requiring re-explanation
- Only surface past context when it genuinely improves the current discussion

## Guidelines for the Assistant

- **Never mention the mechanism**: Don't reference "past sessions", "previous conversations", or "stored knowledge" unless directly relevant to answering the user's question
- **Natural integration**: Weave context into responses as if it's part of current understanding
- **Relevance first**: Only use past context when it genuinely helps the current task
- **Stay focused**: Don't bring up unrelated past topics
- **Be seamless**: The user shouldn't notice the distinction between current session knowledge and retrieved context
