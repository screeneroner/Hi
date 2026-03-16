LMStudio_ChatCompletion(userText, systemText, model, baseUrl, apiKey) {
    endpoint := RTrim(baseUrl, "/") "/chat/completions"
    body := '{"model":' LMStudio_JsonQuote(model) ',"messages":[{"role":"system","content":' LMStudio_JsonQuote(systemText) '},{"role":"user","content":' LMStudio_JsonQuote(userText) '}],"stream":false}'

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
        throw Error("LM Studio HTTP " status "`r`n" resp)

    return LMStudio_ExtractContent(resp)
}

LMStudio_ListModels(baseUrl, apiKey) {
    endpoint := RTrim(baseUrl, "/") "/models"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(5000, 5000, 15000, 15000)
    req.Open("GET", endpoint, false)
    if apiKey != ""
        req.SetRequestHeader("Authorization", "Bearer " apiKey)
    req.Send()

    status := req.Status
    resp := req.ResponseText
    if status < 200 || status >= 300
        throw Error("LM Studio HTTP " status "`r`n" resp)

    ids := LMStudio_ExtractModelIds(resp)
    if ids = ""
        return []
    ids := StrReplace(ids, "\r\n", "`n")
    ids := StrReplace(ids, "\n", "`n")
    ids := StrReplace(ids, "\r", "`n")
    return StrSplit(ids, "`n", "`r")
}

LMStudio_ExtractModelIds(respJson) {
    js := '(function(){try{var o=JSON.parse(' LMStudio_JsQuote(respJson) ');if(!o||!o.data||!o.data.length)return "";return o.data.map(function(x){return x.id||"";}).filter(Boolean).join("\n");}catch(e){return "";}})()'
    return LMStudio_JsEval(js)
}

LMStudio_ExtractContent(respJson) {
    js := '(function(){try{var o=JSON.parse(' LMStudio_JsQuote(respJson) ');return (o.choices&&o.choices[0]&&o.choices[0].message&&o.choices[0].message.content)||"";}catch(e){return "";}})()'
    out := LMStudio_JsEval(js)
    if out = ""
        throw Error("LM Studio response parse failed")
    return out
}

LMStudio_JsEval(expr) {
    doc := ComObject("htmlfile")
    doc.write("<meta http-equiv='X-UA-Compatible' content='IE=9'>")
    return doc.parentWindow.eval(expr)
}

LMStudio_JsQuote(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, '"', '\"')
    return '"' s '"'
}

LMStudio_JsonQuote(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, '"', '\"')
    return '"' s '"'
}
