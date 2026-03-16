global gPromptsPreview := Map()
global gPromptsPendingTooltipKey := ""
global gPromptsPendingTooltipText := ""
global gPromptsPendingTooltipHwnd := 0
global gPromptsPreviewTimerId := 0x5052

Prompts_AddToMenu(m, guiHwnd, editHwnd) {
    global gPromptsPreview
    Prompts_EnablePreviewTooltips()
    gPromptsPreview.Clear()

    path := Prompts_GetPath()
    if !FileExist(path) {
        try {
            FileAppend(Prompts_DemoContent(), path, "UTF-8")
        } catch {
            label := "(prompts file not found)"
            m.Add(label, (*) => 0)
            m.Disable(label)
            return
        }
    }

    iconFolder := 4
    iconDoc := 71

    text := FileRead(path, "UTF-8")
    lines := StrSplit(text, "`n", "`r")

    stack := []

    for i, line in lines {
        if Prompts_ParseHeading(line, &level, &title) {
            while stack.Length > 0 && stack[stack.Length].level >= level {
                node := stack.Pop()
                if !node.isContainer {
                    prompt := RTrim(node.text, "`r`n")
                    node.parentMenu.Add(node.title, Prompts_MenuInsert.Bind(guiHwnd, editHwnd, prompt))
                    node.parentMenu.SetIcon(node.title, "shell32.dll", iconDoc)
                    Prompts_RegisterPreview(node.parentMenu, prompt)
                }
            }

            parentMenu := m
            j := stack.Length
            while j >= 1 {
                if stack[j].isContainer {
                    parentMenu := stack[j].menu
                    break
                }
                j -= 1
            }

            isContainer := Prompts_IsContainer(lines, i, level)
            if isContainer {
                sub := Menu()
                parentMenu.Add(title, sub)
                parentMenu.SetIcon(title, "shell32.dll", iconFolder)
                stack.Push({ level: level, title: title, isContainer: true, menu: sub })
            } else {
                stack.Push({ level: level, title: title, isContainer: false, parentMenu: parentMenu, text: "" })
            }
            continue
        }

        if stack.Length > 0 && !stack[stack.Length].isContainer
            stack[stack.Length].text .= line "`r`n"
    }

    while stack.Length > 0 {
        node := stack.Pop()
        if !node.isContainer {
            prompt := RTrim(node.text, "`r`n")
            node.parentMenu.Add(node.title, Prompts_MenuInsert.Bind(guiHwnd, editHwnd, prompt))
            node.parentMenu.SetIcon(node.title, "shell32.dll", iconDoc)
            Prompts_RegisterPreview(node.parentMenu, prompt)
        }
    }
}

Prompts_EnablePreviewTooltips() {
    static enabled := false
    if enabled
        return
    enabled := true
    OnMessage(0x011F, Prompts_WM_MENUSELECT)
    OnMessage(0x0113, Prompts_WM_TIMER)
}

Prompts_WM_MENUSELECT(wParam, lParam, msg, hwnd) {
    global gPromptsPreview
    global gPromptsPendingTooltipKey, gPromptsPendingTooltipText, gPromptsPendingTooltipHwnd, gPromptsPreviewTimerId
    item := wParam & 0xFFFF
    flags := (wParam >> 16) & 0xFFFF
    hMenu := lParam

    if item = 0xFFFF && hMenu = 0 {
        gPromptsPendingTooltipKey := ""
        gPromptsPendingTooltipText := ""
        Prompts_StopPreviewTimer()
        ToolTip()
        return
    }
    if flags & 0x0010 {
        gPromptsPendingTooltipKey := ""
        gPromptsPendingTooltipText := ""
        Prompts_StopPreviewTimer()
        ToolTip()
        return
    }

    key := (flags & 0x0400) ? (hMenu ":p:" item) : (hMenu ":i:" item)
    if !gPromptsPreview.Has(key) {
        gPromptsPendingTooltipKey := ""
        gPromptsPendingTooltipText := ""
        Prompts_StopPreviewTimer()
        ToolTip()
        return
    }

    if key != gPromptsPendingTooltipKey {
        ToolTip()
        gPromptsPendingTooltipKey := key
        gPromptsPendingTooltipText := gPromptsPreview[key]
        gPromptsPendingTooltipHwnd := hwnd
        Prompts_StartPreviewTimer(hwnd)
        return
    }
}

Prompts_WM_TIMER(wParam, lParam, msg, hwnd) {
    global gPromptsPendingTooltipKey, gPromptsPendingTooltipText, gPromptsPendingTooltipHwnd, gPromptsPreviewTimerId
    if wParam != gPromptsPreviewTimerId
        return
    if hwnd != gPromptsPendingTooltipHwnd
        return
    Prompts_StopPreviewTimer()
    if gPromptsPendingTooltipKey = "" || gPromptsPendingTooltipText = "" {
        ToolTip()
        return
    }
    ToolTip(gPromptsPendingTooltipText)
}

Prompts_StartPreviewTimer(hwnd) {
    global gPromptsPreviewTimerId
    DllCall("KillTimer", "Ptr", hwnd, "UPtr", gPromptsPreviewTimerId)
    DllCall("SetTimer", "Ptr", hwnd, "UPtr", gPromptsPreviewTimerId, "UInt", 1500, "Ptr", 0)
}

Prompts_StopPreviewTimer() {
    global gPromptsPendingTooltipHwnd, gPromptsPreviewTimerId
    if gPromptsPendingTooltipHwnd {
        DllCall("KillTimer", "Ptr", gPromptsPendingTooltipHwnd, "UPtr", gPromptsPreviewTimerId)
        gPromptsPendingTooltipHwnd := 0
    }
}

Prompts_RegisterPreview(menuObj, prompt) {
    global gPromptsPreview
    hMenu := menuObj.Handle
    count := DllCall("GetMenuItemCount", "Ptr", hMenu, "Int")
    if count <= 0
        return
    pos := count - 1
    id := DllCall("GetMenuItemID", "Ptr", hMenu, "Int", pos, "UInt")
    preview := Prompts_MakePreview(prompt)
    gPromptsPreview[hMenu ":p:" pos] := preview
    if id != 0xFFFFFFFF
        gPromptsPreview[hMenu ":i:" id] := preview
}

Prompts_MakePreview(prompt) {
    s := Trim(prompt, "`r`n`t ")
    if s = ""
        return ""
    s := StrReplace(s, "`r`n", "`n")
    s := StrReplace(s, "`r", "`n")
    maxLen := 420
    if StrLen(s) > maxLen
        s := SubStr(s, 1, maxLen) "`n…"
    return s
}

Prompts_ParseHeading(line, &level, &title) {
    if line = ""
        return false
    if SubStr(line, 1, 1) != "#"
        return false
    level := 0
    while SubStr(line, level + 1, 1) = "#"
        level += 1
    title := Trim(SubStr(line, level + 1))
    return true
}

Prompts_IsContainer(lines, startIndex, level) {
    j := startIndex + 1
    while j <= lines.Length {
        next := lines[j]
        if next = "" {
            j += 1
            continue
        }
        if Prompts_ParseHeading(next, &nextLevel, &nextTitle)
            return nextLevel = level + 1
        return false
    }
    return false
}

Prompts_GetPath() {
    return A_ScriptDir "\prompts.md"
}

Prompts_MenuInsert(guiHwnd, editHwnd, prompt, ItemName, ItemPos, MyMenu) {
    WinActivate("ahk_id " guiHwnd)
    DllCall("SetFocus", "Ptr", editHwnd, "Ptr")
    SendMessage(0xB1, -1, -1, , "ahk_id " editHwnd)
    SendMessage(0xB7, 0, 0, , "ahk_id " editHwnd)
    DllCall("SendMessageW", "Ptr", editHwnd, "UInt", 0x00C2, "Ptr", 1, "Str", prompt, "Ptr")
}

Prompts_DemoContent() {
    return "
(
# Quick summary
Summarize the text in 3 bullets.

Constraints:
- No more than 12 words per bullet.
- Keep the original meaning.
- If dates/numbers exist, preserve them.

# Writing
## Rewrite
### Friendly
Rewrite the text in a friendly tone.

Rules:
- Keep it clear and short.
- Avoid jargon.
- Preserve any proper names and code terms.

### Formal
Rewrite the text in a formal tone suitable for a report.

## Insert disclaimer
Add this disclaimer at the end (keep it on separate lines):

- This is informational and may be incomplete.
- Verify against your source of truth.

## Translate
### EN → RU
Translate to Russian.

Keep formatting:
- Preserve lists and indentation.
- Keep code blocks unchanged.

### RU → EN
Translate to English.

# Engineering
## Bug report
### Short
Summarize:
- Repro steps
- Expected vs actual
- Environment (OS/app version)
- Any logs or errors

### Detailed
Write a full bug report with:
- Repro steps
- Expected vs actual
- Suspected root cause(s)
- Debugging plan (what to check next)
- Proposed fix (if clear)

## Code review
### Quick
Review the code and list issues in bullets.

### Deep
Review for correctness, security, and edge cases.
Provide:
- High risk issues
- Medium risk issues
- Low risk issues
- Suggested refactors

# Rules (how menus are built)
Any number of heading levels is allowed.
A heading becomes a submenu only if the next non-empty line is a heading with exactly one more #.
Otherwise it becomes a clickable item and its text (multi-line supported) is inserted until the next heading.

Preview:
- Hover a clickable prompt item to see a tooltip preview (after a short delay).
)"
}
