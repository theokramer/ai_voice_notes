# Organize Screen Rebuild - Zusammenfassung

## Übersicht
Der Organize Screen wurde komplett umgebaut, um eine klarere und benutzerfreundlichere Organisation von Notizen zu ermöglichen.

## Neue Features

### 1. **Pro-Note Vorschläge**
- **Jede einzelne Notiz** erhält einen eigenen Organisationsvorschlag
- Die AI analysiert jede Notiz individuell und gibt eine Empfehlung ab
- Confidence Score (0-100%) zeigt die Sicherheit der AI-Klassifizierung

### 2. **Gruppierung nach Zielordner**
Die Ansicht ist jetzt nach Zielordnern strukturiert:
- **Ganz oben**: Vorschläge für neue Ordner (grün markiert mit "NEU" Badge)
- **Darunter**: Vorschläge für existierende Ordner
- Jede Gruppe zeigt:
  - Ordner-Icon und Name
  - Anzahl der Notizen für diesen Ordner
  - Durchschnittliche Confidence
  - Anzahl unklarer Zuordnungen

### 3. **Unklar-Markierung bei geringer Confidence**
- Notizen mit Confidence < 60% werden als "unklar" markiert
- Orange Warnung: "Unsichere Zuordnung - Bitte überprüfen"
- Diese Notizen müssen manuell überprüft werden

### 4. **Manuelle Ordner-Auswahl**
Für jede Notiz kann der Benutzer:
- Den vorgeschlagenen Ordner ändern
- Einen existierenden Ordner wählen
- Einen neuen Ordner erstellen
- Button: "Ordner ändern" öffnet Dialog mit allen Optionen

### 5. **Notizen löschen**
- Jede Notiz hat einen Löschen-Button (rotes Papierkorb-Icon)
- Bestätigungsdialog vor dem Löschen
- Notiz wird sofort aus der Liste entfernt

### 6. **Validierung vor "Alle anwenden"**
- Beim Klick auf "Alle anwenden" prüft das System:
  - Gibt es Notizen mit geringer Confidence, die noch nicht überprüft wurden?
  - Falls ja: Warndialog erscheint
  - Dialog: "X Notizen haben keine klare Zuordnung. Bitte überprüfe diese Notizen manuell..."
- Verhindert versehentliches Fehlorganisieren

### 7. **Visuelle Verbesserungen**
- **Neue Ordner**: Grün hervorgehoben mit "NEU" Badge
- **Confidence Badges**: Farbcodiert (Grün > 80%, Orange 60-80%, Rot < 60%)
- **Unklar Counter**: Zeigt pro Ordner-Gruppe an, wie viele Notizen unklar sind
- **Expand/Collapse**: Ordner-Gruppen können ein-/ausgeklappt werden
- **Reasoning**: Jede Notiz zeigt die AI-Begründung in Kursiv

## Technische Änderungen

### Neue Model-Klasse: `NoteOrganizationSuggestion`
```dart
class NoteOrganizationSuggestion {
  final String noteId;
  final double confidence;
  
  // User override fields
  String? userSelectedFolderId;
  String? userSelectedFolderName;
  bool userModified;
  
  bool get needsUserAction => confidence < 0.6 && !userModified;
}
```

### Neue OpenAI Service Methode
`generatePerNoteOrganizationSuggestions()` - Erstellt für jede Notiz eine individuelle Empfehlung

### UI Komponenten
1. `_GroupedSuggestionsView` - Gruppiert Vorschläge nach Zielordner
2. `_FolderGroupCard` - Zeigt eine Ordner-Gruppe mit allen Notizen
3. `_NoteOrganizationCard` - Zeigt einzelne Notiz mit Aktionen
4. `_FolderPickerDialog` - Dialog zur Ordner-Auswahl

## Benutzer-Workflow

1. **Screen öffnen**: Alle unorganisierten Notizen werden analysiert
2. **Vorschläge prüfen**: 
   - Neue Ordner-Vorschläge ganz oben
   - Notizen nach Zielordner gruppiert
   - Unklare Notizen sind orange markiert
3. **Anpassen (optional)**:
   - Ordner für einzelne Notizen ändern
   - Unerwünschte Notizen löschen
   - Neue Ordnernamen bearbeiten
4. **Anwenden**: 
   - "Alle anwenden" klicken
   - System prüft auf unklare Notizen
   - Alle Notizen werden organisiert
   - Neue Ordner werden erstellt

## Vorteile

✅ **Transparenz**: Jede Entscheidung ist nachvollziehbar  
✅ **Kontrolle**: Benutzer kann jede Empfehlung überprüfen und ändern  
✅ **Übersichtlich**: Gruppierung nach Ordnern zeigt sofort die Struktur  
✅ **Sicher**: Warnung bei unklaren Zuordnungen verhindert Fehler  
✅ **Flexibel**: Notizen können gelöscht oder neu zugeordnet werden  
✅ **Effizient**: Klare Priorisierung (neue Ordner zuerst)  

## Internationalisierung

Alle UI-Texte sind auf Deutsch:
- "Notizen organisieren"
- "Alle anwenden"
- "Ordner ändern"
- "Unsichere Zuordnung - Bitte überprüfen"
- "Unklare Notizen" (Warndialog)
- etc.

