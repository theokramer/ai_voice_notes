# AI Chat Testing Guide

## Prerequisites
- Ensure `OPENAI_API_KEY` is set in your `.env` file
- Have a few test notes in different folders
- Test with both empty and populated notes database

## Test Scenarios

### 1. Query Notes (Basic Functionality)

**Test 1.1: Simple Query**
```
User: "What notes do I have about meetings?"
Expected: AI searches notes and provides answer with note citations
Action: Click on note citation → Should open the note
```

**Test 1.2: No Results**
```
User: "What did I note about quantum physics?"
Expected: AI responds that no notes were found on that topic
```

**Test 1.3: Multilingual Query**
```
User: "Was habe ich über Arbeit notiert?" (German)
Expected: AI responds in German with note citations
```

### 2. Create Note Action

**Test 2.1: Basic Note Creation**
```
User: "Create a note about grocery shopping"
Expected:
- AI responds: "I'll create a new note for your grocery shopping list."
- Shows "Create Note" button
- Click button → Note created immediately
- Success message appears: "✅ Created note 'Grocery Shopping'!"
- Undo snackbar appears for 4 seconds
- Automatically navigates to new note
```

**Test 2.2: Note Creation with Content**
```
User: "Create a note called Meeting Notes with content: Discussed Q3 goals"
Expected: 
- Note created with both name and content
- Content appears in the note when opened
```

**Test 2.3: Undo Note Creation**
```
User: "Create a note about test"
Action: Click "Create Note" button
Action: Click "UNDO" in snackbar within 4 seconds
Expected: Note is deleted
```

### 3. Add to Note Action

**Test 3.1: Add Content to Existing Note**
```
Prerequisite: Create a note called "Shopping List"
User: "Add buy milk to my shopping list"
Expected:
- AI finds the shopping list note
- Shows "Add to Note" button
- Click button → Content "buy milk" appended
- Success message: "✅ Added content to 'Shopping List'!"
- Undo snackbar available
```

**Test 3.2: Note Not Found**
```
User: "Add something to my xyz note"
Expected: "❌ Could not find that note."
```

**Test 3.3: Undo Add Content**
```
User: "Add test content to my shopping list"
Action: Click "Add to Note" button
Action: Click "UNDO" in snackbar
Expected: Content is removed from note
```

### 4. Move Note Action

**Test 4.1: Move Note to Folder**
```
Prerequisite: Have a note and a folder
User: "Move my meeting notes to work folder"
Expected:
- AI identifies the note and folder
- Shows "Move Note" button
- Click button → Note moved
- Success message: "✅ Moved 'Meeting Notes' to Work!"
- Undo snackbar available
```

**Test 4.2: Undo Move**
```
Action: Move a note to different folder
Action: Click "UNDO"
Expected: Note returns to original folder
```

### 5. Create Folder Action

**Test 5.1: Create Folder with Smart Emoji**
```
User: "Create a folder for health notes"
Expected:
- AI proposes creating folder
- Shows "Create Folder" button
- Click button → Folder created with health emoji (🏥)
- Success message: "✅ Created folder 'Health' 🏥!"
- Undo snackbar available
```

**Test 5.2: Duplicate Folder**
```
Prerequisite: Have a folder called "Work"
User: "Create a folder called work"
Expected: "✅ Folder 'Work' already exists!"
```

**Test 5.3: Various Folder Types**
```
Test these and verify correct emoji:
- "Create folder for work" → 💼
- "Create folder for personal thoughts" → 💭
- "Create folder for ideas" → 💡
- "Create folder for learning" → 📚
- "Create folder for finance" → 💰
```

**Test 5.4: Undo Folder Creation**
```
Action: Create a new folder
Action: Click "UNDO"
Expected: Folder is deleted
```

### 6. Summarize Chat Action

**Test 6.1: Summarize Conversation**
```
Action: Have a conversation with AI (3-4 messages)
User: "Summarize our conversation"
Expected:
- Shows "🤔 Creating summary..." temporarily
- AI generates comprehensive summary
- Creates note automatically
- Success message: "✅ Created chat summary note!"
- Snackbar shows "VIEW" button
- Click "VIEW" → Opens summary note
```

**Test 6.2: Check Summary Quality**
```
Expected summary should include:
- All important points discussed
- Questions asked and answers provided
- Clear sections and organization
- Readable format with bullet points
```

**Test 6.3: Alternative Phrasings**
```
Try these:
- "Create a note from this chat"
- "Save our conversation"
- "Make a summary note"
All should trigger the same action
```

### 7. Pin Note Action

**Test 7.1: Pin Note**
```
User: "Pin my shopping list note"
Expected:
- AI identifies the note
- Shows "Pin Note" button
- Click button → Note is pinned
- Success message: "✅ Pinned 'Shopping List'!"
- Note appears at top of list
```

**Test 7.2: Unpin Note**
```
Prerequisite: Have a pinned note
User: "Unpin my shopping list"
Expected:
- Note is unpinned
- Success message: "✅ Unpinned 'Shopping List'!"
```

**Test 7.3: Undo Pin/Unpin**
```
Action: Pin or unpin a note
Action: Click "UNDO"
Expected: Pin state is restored
```

### 8. Delete Note Action

**Test 8.1: Delete Note with Confirmation**
```
User: "Delete my test note"
Expected:
- AI identifies the note
- Shows "Delete Note" button
- Click button → Confirmation dialog appears
- Dialog asks: "Are you sure you want to delete 'Test Note'?"
- Click "Delete" → Note is deleted
- Success message: "✅ Deleted 'Test Note'."
- Undo snackbar available
```

**Test 8.2: Cancel Delete**
```
User: "Delete my note"
Action: Click "Delete Note" button
Action: Click "Cancel" in confirmation dialog
Expected: Note is NOT deleted, chat continues normally
```

**Test 8.3: Undo Delete**
```
Action: Delete a note
Action: Click "UNDO"
Expected: Note is restored
```

### 9. Error Handling

**Test 9.1: Malformed Request**
```
User: "Create a note" (no name provided)
Expected: AI asks for more information or creates note with timestamp name
```

**Test 9.2: Network Error**
```
Action: Disconnect internet
User: Send message to AI
Expected: Error message shown, chat doesn't crash
```

**Test 9.3: API Key Missing**
```
Action: Remove OPENAI_API_KEY from .env
Expected: Error message shown, app doesn't crash
```

### 10. Chat Persistence

**Test 10.1: Chat Stays Open After Action**
```
Action: Perform any action (create note, etc.)
Expected: Chat overlay remains open
User: Can continue conversation immediately
```

**Test 10.2: Navigate and Return**
```
Action: Open a note from citation
Action: Press back
Expected: Return to chat with full conversation history
```

### 11. Multiple Languages

**Test 11.1: German**
```
User: "Erstelle eine Notiz über Einkaufen"
Expected: AI responds in German with appropriate action
```

**Test 11.2: Spanish**
```
User: "Crea una nota sobre reuniones"
Expected: AI responds in Spanish with appropriate action
```

**Test 11.3: Language Switching**
```
User: First message in English
User: Second message in German
Expected: AI responds in respective language for each message
```

### 12. Edge Cases

**Test 12.1: Empty Notes Database**
```
Prerequisite: Delete all notes
User: "What notes do I have?"
Expected: AI responds that there are no notes yet
```

**Test 12.2: Many Notes**
```
Prerequisite: Create 30+ notes
User: "Find my notes about..."
Expected: AI can still search and find relevant notes
```

**Test 12.3: Long Conversation**
```
Action: Have 10+ message exchanges
User: "Summarize our chat"
Expected: Summary includes all important points
```

**Test 12.4: Special Characters**
```
User: "Create a note called 'Test @#$%'"
Expected: Note created with special characters intact
```

## Performance Tests

**Test P1: Response Time**
```
Expected: AI response within 2-5 seconds
```

**Test P2: Action Execution**
```
Expected: Actions execute immediately (<500ms)
```

**Test P3: Undo Speed**
```
Expected: Undo completes instantly
```

## UI/UX Tests

**Test UI1: Action Button Visibility**
```
Expected: Action buttons are prominent and clearly labeled
```

**Test UI2: Success Messages**
```
Expected: All success messages use ✅ emoji and are clear
```

**Test UI3: Error Messages**
```
Expected: All error messages use ❌ emoji and are helpful
```

**Test UI4: Snackbar Timing**
```
Expected: Snackbar appears for exactly 4 seconds
Expected: Can interact with snackbar within timeout
```

## Regression Tests

**Test R1: Existing Chat Features**
```
Verify that original chat features still work:
- Ask AI button appears when searching
- Chat opens with query context
- Citations work correctly
```

**Test R2: Note Operations**
```
Verify existing note operations still work:
- Create note manually
- Edit note
- Delete note manually
- Move note manually
```

## Sign-Off Checklist

- [ ] All basic query tests pass
- [ ] All 7 action types work correctly
- [ ] Undo works for all action types
- [ ] Error handling works correctly
- [ ] Multilingual support verified
- [ ] Chat persists through actions
- [ ] Performance is acceptable
- [ ] UI/UX is polished
- [ ] No crashes or freezes
- [ ] App builds successfully

## Known Issues (to be documented during testing)

_Add any issues discovered during testing here_

## Notes

- Test with both iOS and Android if possible
- Test with various screen sizes
- Test with different AI response variations
- Document any unexpected behaviors
- Note any performance bottlenecks

