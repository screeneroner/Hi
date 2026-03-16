#Requires AutoHotkey v2.0
#SingleInstance Force
#Include settings.ahk
#Include prompts.ahk
#Include lmstudio.ahk
#Include ollama.ahk

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;
; AI Temp Chat (AutoHotkey v2)
; - Win+Alt+A toggles a small chat window with a single multiline input.
; - Ctrl+Enter sends the current edit text to the selected engine and appends the response below a divider.
; - Engines: Claude (CLI), LM Studio (OpenAI-compatible HTTP API), Ollama (HTTP API).
; - Optional: best-effort hiding of newly spawned Claude console windows.

global gEditOldProc := 0
global gEditNewProc := 0
Settings_Init()
SetupTrayMenu()

; UI setup (single Edit control)
gGui := Gui("+Resize ", gBaseTitle)
gGui.MarginX := 5
gGui.MarginY := 5
gGui.BackColor := clrDark
gGui.SetFont("s10 c" clrLight, "Segoe UI")
gEdit := gGui.AddEdit("xm ym w760 h420 WantReturn VScroll -Border -E0x200 Background" clrDark)
gCtxMenu := BuildEditContextMenu()
InstallEditSubclass()

if !gGui.Hwnd {
    gGui.Show("Hide")
    gGui.Hide()
}
HotIf((*) => WinActive("ahk_id " gGui.Hwnd))
Hotkey("$*Enter", GuiEnterKey, "On")
HotIf()

; Window events
gGui.OnEvent("Close", (*) => gGui.Hide())
gGui.OnEvent("Escape", (*) => gGui.Hide())
gGui.OnEvent("Size", GuiSize)

; Global toggle hotkey
#!a::ToggleGui()

SetupTrayMenu() {
    A_IconTip := "Hi - AI Temp Chat`nby screeneroner`nv3.05-20260315"
    m := A_TrayMenu
    try m.Delete()
    labelOpen := "Open (Win+Alt+A)"
    m.Add(labelOpen, (*) => ToggleGui())
    m.Default := labelOpen
    m.Add()
    m.Add("Exit", (*) => ExitApp())
}

; Toggle the chat window.
; If the edit is empty, tries to grab the current selection from the previously active app (clipboard is restored).
ToggleGui() {
    global gGui, gEdit
    if WinActive("ahk_id " gGui.Hwnd)
        return gGui.Hide()
    if Trim(gEdit.Value) = "" {
        clipSaved := ClipboardAll()
        A_Clipboard := ""
        Send("^c")
        ClipWait(0.2)
        sel := A_Clipboard
        A_Clipboard := clipSaved
        if sel != "" {
            gEdit.Value := sel
        }
    }
    gGui.Show()
    ApplyTheme()
    gEdit.Focus()
    SendMessage(0xB1, -1, -1, , "ahk_id " gEdit.Hwnd)
    SendMessage(0xB7, 0, 0, , "ahk_id " gEdit.Hwnd)
    ; WinSetTransparent(250, "ahk_id " gGui.Hwnd)
}

GuiEnterKey(*) {
    global gGui, gEdit
    ctrl := gGui.FocusedCtrl
    if !IsObject(ctrl) || ctrl.Hwnd != gEdit.Hwnd {
        Send("{Enter}")
        return
    }
    if GetKeyState("Ctrl", "P") {
        SendPrompt()
        return
    }
    Send("{Enter}")
}

; Resizes the edit control to fill the window with margins.
GuiSize(gui, minMax, width, height) {
    global gEdit
    if minMax = -1
        return
    if minMax = 1
        return gui.Hide()
    x := gui.MarginX, y := gui.MarginY
    gEdit.Move(x, y, Max(50, width - 2 * x), Max(50, height - 2 * y))
}

BuildEditContextMenu() {
    global gGui, gEdit, gIsDarkTheme
    m := Menu()

    eng := Menu()
    global gEngineMenuRef := eng
    eng.Add("Claude", EngineMenuHandler.Bind("Claude"))
    eng.Add("Thinking Effort", BuildEffortMenu())
    eng.Add()
    eng.Add("LM Studio", EngineMenuHandler.Bind("LM Studio"))
    eng.Add("Ollama", EngineMenuHandler.Bind("Ollama"))
    EngineMenuSyncChecks(eng)
    eng.Add()
    eng.Add("Select Model", BuildModelMenu())
    m.Add("Engine", eng)
    m.Add()

    Prompts_AddToMenu(m, gGui.Hwnd, gEdit.Hwnd)
    m.Add()
    m.Add("Dark Theme", ToggleDarkThemeMenu)
    if gIsDarkTheme
        m.Check("Dark Theme")
    else
        m.Uncheck("Dark Theme")
    m.Add("Send (Ctrl+Enter)", (*) => SendPrompt())
    return m
}

EngineMenuSyncChecks(m) {
    global gEngine
    for label in ["Claude", "LM Studio", "Ollama"]
        m.Uncheck(label)
    if gEngine = "Claude"
        m.Check("Claude")
    else if gEngine = "LM Studio"
        m.Check("LM Studio")
    else if gEngine = "Ollama"
        m.Check("Ollama")
    else
        m.Check("LM Studio")
}

EngineMenuHandler(engine, ItemName, ItemPos, MyMenu) {
    global gEngine, gEngineMenuRef
    gEngine := engine
    EngineMenuSyncChecks(IsObject(gEngineMenuRef) ? gEngineMenuRef : MyMenu)
}

BuildModelMenu() {
    global gEngine, gModelClaude, gModelLMS, gModelOllama, LMS_BASE_URL, LMS_API_KEY
    m := Menu()
    if gEngine = "LM Studio" {
        try models := LMStudio_ListModels(LMS_BASE_URL, LMS_API_KEY)
        catch as e {
            msg := "(error loading models)"
            m.Add(msg, (*) => 0)
            m.Disable(msg)
            return m
        }
        if models.Length = 0 {
            msg := "(no models)"
            m.Add(msg, (*) => 0)
            m.Disable(msg)
            return m
        }
        for id in models {
            m.Add(id, ModelMenuHandler.Bind("LM Studio", id))
            if id = gModelLMS
                m.Check(id)
        }
    } else if gEngine = "Claude" {
        models := ["default", "sonnet", "opus", "haiku", "opusplan"]
        for id in models {
            m.Add(id, ModelMenuHandler.Bind("Claude", id))
            if id = gModelClaude
                m.Check(id)
        }
    } else if gEngine = "Ollama" {
        try models := Ollama_ListModels(OLLAMA_BASE_URL, OLLAMA_API_KEY)
        catch as e {
            msg := "(error loading models)"
            m.Add(msg, (*) => 0)
            m.Disable(msg)
            return m
        }
        if models.Length = 0 {
            msg := "(no models)"
            m.Add(msg, (*) => 0)
            m.Disable(msg)
            return m
        }
        for id in models {
            m.Add(id, ModelMenuHandler.Bind("Ollama", id))
            if id = gModelOllama
                m.Check(id)
        }
    } else {
        m.Add("(not implemented yet)", (*) => 0)
        m.Disable("(not implemented yet)")
    }
    return m
}

ModelMenuHandler(engine, modelId, ItemName, ItemPos, MyMenu) {
    global gModelClaude, gModelLMS, gModelOllama
    if engine = "Claude" {
        old := gModelClaude
        gModelClaude := modelId
    } else if engine = "LM Studio" {
        old := gModelLMS
        gModelLMS := modelId
    } else if engine = "Ollama" {
        old := gModelOllama
        gModelOllama := modelId
    } else {
        return
    }
    try MyMenu.Uncheck(old)
    try MyMenu.Check(modelId)
}

BuildEffortMenu() {
    global gEffort
    m := Menu()
    m.Add("Low", EffortMenuHandler.Bind("low"))
    m.Add("Medium", EffortMenuHandler.Bind("medium"))
    m.Add("High", EffortMenuHandler.Bind("high"))
    m.Add("Max", EffortMenuHandler.Bind("max"))
    EffortMenuSyncChecks(m)
    return m
}

EffortMenuSyncChecks(m) {
    global gEffort
    for label in ["Low", "Medium", "High", "Max"]
        m.Uncheck(label)
    label := (gEffort = "low") ? "Low" : (gEffort = "medium") ? "Medium" : (gEffort = "high") ? "High" : "Max"
    m.Check(label)
}

EffortMenuHandler(effort, ItemName, ItemPos, MyMenu) {
    global gEffort
    gEffort := effort
    EffortMenuSyncChecks(MyMenu)
}

ToggleDarkThemeMenu(ItemName, ItemPos, MyMenu) {
    global gIsDarkTheme
    gIsDarkTheme := !gIsDarkTheme
    if gIsDarkTheme
        MyMenu.Check(ItemName)
    else
        MyMenu.Uncheck(ItemName)
    ApplyTheme()
}

ApplyTheme() {
    global gGui, gEdit, gIsDarkTheme, clrDark, clrLight
    if gIsDarkTheme {
        gGui.BackColor := clrDark
        gEdit.Opt("Background" clrDark)
        gEdit.SetFont("c" clrLight)
        EnableDarkTheme(gGui.Hwnd)
        EnableDarkTheme(gEdit.Hwnd)
    } else {
        gGui.BackColor := clrLight
        gEdit.Opt("Background" clrLight)
        gEdit.SetFont("c" clrDark)
        DisableDarkTheme(gGui.Hwnd)
        DisableDarkTheme(gEdit.Hwnd)
    }
    try gGui.Redraw()
}

InstallEditSubclass() {
    global gEdit, gEditOldProc, gEditNewProc
    if gEditNewProc
        return
    gEditNewProc := CallbackCreate(EditWndProc, "Fast", 4)
    gEditOldProc := DllCall("SetWindowLongPtr", "Ptr", gEdit.Hwnd, "Int", -4, "Ptr", gEditNewProc, "Ptr")
}

EditWndProc(hwnd, msg, wParam, lParam) {
    global gCtxMenu, gEditOldProc
    if msg = 0x007B {
        gCtxMenu := BuildEditContextMenu()
        gCtxMenu.Show()
        return 0
    }
    return DllCall("CallWindowProc", "Ptr", gEditOldProc, "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
}

; Sends the current edit text to the selected engine.
; UI behavior:
; - Inserts a divider line before sending.
; - Appends the model output after the divider.
SendPrompt() {
    global gGui, gEdit, gQuery, gEngine, gModelClaude, gModelLMS, gModelOllama, gEffort, gHideConsole, LMS_BASE_URL, LMS_API_KEY, OLLAMA_BASE_URL, OLLAMA_API_KEY
    context := Trim(gEdit.Value, "`r`n `t")
    if !context
        return

    model := (gEngine = "LM Studio") ? gModelLMS : (gEngine = "Claude") ? gModelClaude : gModelOllama
    SetCaptionBusy(true, gEngine, model)
    base := gEdit.Value
    if base != "" && SubStr(base, -1) != "`n"
        base .= "`r`n"
    base .= "-----`r`n"
    gEdit.Value := base
    WinActivate("ahk_id " gGui.Hwnd), gEdit.Focus(), Send("^{End}")

    if gEngine = "LM Studio" {
        try {
            out := LMStudio_ChatCompletion(context, gQuery ? gQuery : "Answer the text provided in the message.", gModelLMS, LMS_BASE_URL, LMS_API_KEY)
        } catch as e {
            out := "ERROR: " e.Message
        }
    } else if gEngine = "Claude" {
        try {
            out := ClaudeCLI_Run(context, gModelClaude)
        } catch as e {
            out := "ERROR: " e.Message
        }
    } else if gEngine = "Ollama" {
        try {
            out := Ollama_Generate(context, gModelOllama, OLLAMA_BASE_URL, OLLAMA_API_KEY)
        } catch as e {
            out := "ERROR: " e.Message
        }
    } else {
        out := "ERROR: Engine not implemented yet"
    }
    gEdit.Value := base out "`r`n`r`n"
    A_Clipboard := out
    WinActivate("ahk_id " gGui.Hwnd), gEdit.Focus(), Send("^{End}")
    SetCaptionBusy(false, gEngine, model)
}

SetCaptionBusy(isBusy, engine, model) {
    global gGui
    prefix := isBusy ? ">" : "<"
    gGui.Title := prefix " " StrUpper(engine) ": " model
}

ClaudeCLI_Run(input, model) {
    global gQuery, gEffort, gHideConsole
    EnvSet("ANTHROPIC_API_KEY")
    if gHideConsole
        old := SnapshotConsoleWindows()

    exec := ComObject("WScript.Shell").Exec('claude --model ' model ' --effort ' gEffort ' -p "' (gQuery ? gQuery : "Answer the text provided on stdin.") '" --output-format text')

    if gHideConsole
        HideNewConsoleWindows(old)

    exec.StdIn.Write(input)
    exec.StdIn.Close()
    out := exec.StdOut.ReadAll()
    return FixMaybeUtf8Mojibake(out)
}

FixMaybeUtf8Mojibake(s) {
    if s = ""
        return s
    if !(InStr(s, "Ð") || InStr(s, "Ã") || InStr(s, "â"))
        return s

    bufSize := StrPut(s, "CP1252")
    buf := Buffer(bufSize)
    StrPut(s, buf, "CP1252")
    if StrGet(buf, "CP1252") != s
        return s
    return StrGet(buf, "UTF-8")
}

; Captures currently open console windows so we can detect new ones spawned by Claude.
SnapshotConsoleWindows() {
    old := Map()
    for h in WinGetList("ahk_class ConsoleWindowClass")
        old[h] := 1
    return old
}

; Best-effort console hiding: polls briefly for new ConsoleWindowClass windows and hides them.
HideNewConsoleWindows(old) {
    Loop 20 {
        Sleep 25
        for h in WinGetList("ahk_class ConsoleWindowClass")
            if !old.Has(h)
                WinHide("ahk_id " h), old[h] := 1
    }
}

; Best-effort dark mode theming for a window/control (Win10/11).
EnableDarkTheme(hwnd) {
    v := 1
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "IntP", &v, "Int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 19, "IntP", &v, "Int", 4)
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

DisableDarkTheme(hwnd) {
    v := 0
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "IntP", &v, "Int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 19, "IntP", &v, "Int", 4)
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "Explorer", "Ptr", 0)
}

