Ollama_Generate(promptText, model, baseUrl, apiKey) {
    endpoint := RTrim(baseUrl, "/") "/api/generate"
    body := '{"model":' Ollama_JsonQuote(model) ',"prompt":' Ollama_JsonQuote(promptText) ',"stream":false}'

    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(5000, 5000, 30000, 30000)
    req.Open("POST", endpoint, false)
    req.SetRequestHeader("Content-Type", "application/json")
    if apiKey != ""
        req.SetRequestHeader("Authorization", "Bearer " apiKey)
    req.Send(body)

    status := req.Status
    resp := req.ResponseText
    if status < 200 || status >= 300
        throw Error("Ollama HTTP " status "`r`n" resp)

    return Ollama_ExtractResponse(resp)
}

Ollama_ListModels(baseUrl, apiKey) {
    endpoint := RTrim(baseUrl, "/") "/api/tags"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(5000, 5000, 15000, 15000)
    req.Open("GET", endpoint, false)
    if apiKey != ""
        req.SetRequestHeader("Authorization", "Bearer " apiKey)
    req.Send()

    status := req.Status
    resp := req.ResponseText
    if status < 200 || status >= 300
        throw Error("Ollama HTTP " status "`r`n" resp)

    ids := Ollama_ExtractModelNames(resp)
    if ids = ""
        return []
    ids := StrReplace(ids, "\r\n", "`n")
    ids := StrReplace(ids, "\n", "`n")
    ids := StrReplace(ids, "\r", "`n")
    return StrSplit(ids, "`n", "`r")
}

Ollama_ExtractModelNames(respJson) {
    js := '(function(){try{var o=JSON.parse(' Ollama_JsQuote(respJson) ');if(!o||!o.models||!o.models.length)return "";return o.models.map(function(x){return x.name||"";}).filter(Boolean).join("\n");}catch(e){return "";}})()'
    return Ollama_JsEval(js)
}

Ollama_ExtractResponse(respJson) {
    js := '(function(){try{var o=JSON.parse(' Ollama_JsQuote(respJson) ');return (o.response)||((o.message&&o.message.content)||"");}catch(e){return "";}})()'
    out := Ollama_JsEval(js)
    if out = ""
        throw Error("Ollama response parse failed")
    return out
}

Ollama_JsEval(expr) {
    doc := ComObject("htmlfile")
    doc.write("<meta http-equiv='X-UA-Compatible' content='IE=9'>")
    return doc.parentWindow.eval(expr)
}

Ollama_JsQuote(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, '"', '\"')
    return '"' s '"'
}

Ollama_JsonQuote(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, '"', '\"')
    return '"' s '"'
}
