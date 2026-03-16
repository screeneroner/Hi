global gQuery := "Answer the text provided on stdin."
global gEngine := "LM Studio"
global gModelClaude := "default"
global gModelLMS := "default"
global gModelOllama := "llama3"
global gEffort := "low"
global gHideConsole := true

global LMS_BASE_URL := "http://localhost:1234/v1"
global LMS_API_KEY := ""
global OLLAMA_BASE_URL := "http://localhost:11434"
global OLLAMA_API_KEY := ""

global gIsDarkTheme := true
global clrDark := "191D22"
global clrLight := "f0f0f0"

global gIniPath := A_ScriptDir "\settings.ini"
global gBaseTitle := "AI TEMP CHAT   ( CTRL+ENTER - send message;  WIN+ALT+A - toggle chat window )"

Settings_Init() {
    LoadSettings()
    OnExit(SaveSettingsOnExit)
}

LoadSettings() {
    global gIniPath, gEngine, gEffort, gHideConsole, gIsDarkTheme
    global gModelClaude, gModelLMS, gModelOllama
    global LMS_BASE_URL, LMS_API_KEY, OLLAMA_BASE_URL, OLLAMA_API_KEY
    try {
        gEngine := IniRead(gIniPath, "General", "Engine", gEngine)
        if !(gEngine = "Claude" || gEngine = "LM Studio" || gEngine = "Ollama")
            gEngine := "LM Studio"
        gEffort := IniRead(gIniPath, "General", "Effort", gEffort)
        gHideConsole := IniRead(gIniPath, "General", "HideConsole", gHideConsole ? 1 : 0) = 1
        gIsDarkTheme := IniRead(gIniPath, "General", "DarkTheme", gIsDarkTheme ? 1 : 0) = 1

        gModelClaude := IniRead(gIniPath, "Claude", "Model", gModelClaude)
        gModelLMS := IniRead(gIniPath, "LM Studio", "Model", gModelLMS)
        gModelOllama := IniRead(gIniPath, "Ollama", "Model", gModelOllama)

        LMS_BASE_URL := IniRead(gIniPath, "LM Studio", "URL", LMS_BASE_URL)
        LMS_API_KEY := IniRead(gIniPath, "LM Studio", "APIKey", LMS_API_KEY)

        OLLAMA_BASE_URL := IniRead(gIniPath, "Ollama", "URL", OLLAMA_BASE_URL)
        OLLAMA_API_KEY := IniRead(gIniPath, "Ollama", "APIKey", OLLAMA_API_KEY)
    } catch {
    }
}

SaveSettings() {
    global gIniPath, gEngine, gEffort, gHideConsole, gIsDarkTheme
    global gModelClaude, gModelLMS, gModelOllama
    global LMS_BASE_URL, LMS_API_KEY, OLLAMA_BASE_URL, OLLAMA_API_KEY

    IniWrite(gEngine, gIniPath, "General", "Engine")
    IniWrite(gEffort, gIniPath, "General", "Effort")
    IniWrite(gHideConsole ? 1 : 0, gIniPath, "General", "HideConsole")
    IniWrite(gIsDarkTheme ? 1 : 0, gIniPath, "General", "DarkTheme")

    IniWrite(gModelClaude, gIniPath, "Claude", "Model")
    IniWrite(gModelLMS, gIniPath, "LM Studio", "Model")
    IniWrite(gModelOllama, gIniPath, "Ollama", "Model")

    IniWrite(LMS_BASE_URL, gIniPath, "LM Studio", "URL")
    IniWrite(LMS_API_KEY, gIniPath, "LM Studio", "APIKey")

    IniWrite(OLLAMA_BASE_URL, gIniPath, "Ollama", "URL")
    IniWrite(OLLAMA_API_KEY, gIniPath, "Ollama", "APIKey")
}

SaveSettingsOnExit(ExitReason, ExitCode) {
    SaveSettings()
}
