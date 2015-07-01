
XIncludeFile "MainForm.pbf"
UseJPEGImageDecoder()

;- Declares
Declare GetCaptchaThread(Dummy)
Declare GetCaptcha()
Declare Login(Login$, Pass$, Captcha$)
Declare LoginThread(Parameters)
Declare Traffic(StartDate$, EndDate$)
Declare TrafficThread(TrafficParam)

;- Structures
Structure LoginStructure
    Login$
    Pass$
    Captcha$
EndStructure

Structure TrafficStructure
    StartDate$
    EndDate$
EndStructure

;- Constants
#SHOW_GADGET = 1
#HIDE_GADGET = 0

#DISABLE_GADGET = 1
#ENABLE_GADGET = 0

#KEYBOARD_ENTER = 10
#MAX_GADGET_COUNT = 21
Enumeration File
    #FILE_CABINET
    #FILE_TRAFFIC
EndEnumeration

Enumeration Image
    #IMAGE_CAPTCHA
    #IMAGE_LOADING
EndEnumeration

Enumeration RegExp
    #REGEXP_PERSONROOM
    #REGEXP_TRAFFIC
EndEnumeration

;- Global variables
Global PassParameters.LoginStructure
InitKeyboard()
OpenWindow_0()
For i = 0 To 7
    HideGadget(i, #HIDE_GADGET)
Next
For i = 8 To #MAX_GADGET_COUNT
    HideGadget(i, #SHOW_GADGET)
Next
CreateThread(@GetCaptchaThread(), #Null)
; SetGadgetText(#LOGIN_COMBO, "aa75-2240924")
; SetGadgetText(#PASS_INPUT, "zigota0511")
AddKeyboardShortcut(0, #PB_Shortcut_Return, #KEYBOARD_ENTER)

Procedure Window_0_EventsMy(event)
    Select event
        Case #PB_Event_CloseWindow
            ProcedureReturn #False
            
        Case #PB_Event_Menu
            Select EventMenu()
                Case #KEYBOARD_ENTER
                    PostEvent(#PB_Event_Gadget, 0, #ENTER_BUTTON)
            EndSelect
            
        Case #PB_Event_Gadget
            Select EventGadget()
                Case #CAPTCHA_GADGET
                    Select EventType()
                        Case #PB_EventType_LeftClick        : CreateThread(@GetCaptchaThread(), #Null)
                        Case #PB_EventType_RightClick       : Debug "Click with right mouse button"
                        Case #PB_EventType_LeftDoubleClick  : Debug "Double-click with left mouse button"
                        Case #PB_EventType_RightDoubleClick : Debug "Double-click with right mouse button"
                    EndSelect
                    
                Case #ENTER_BUTTON
                    PassParameters\Login$ = GetGadgetText(#LOGIN_COMBO)
                    PassParameters\Pass$ = GetGadgetText(#PASS_INPUT)
                    PassParameters\Captcha$ = GetGadgetText(#CAPTCHA_INPUT)
                    If PassParameters\Captcha$ = ""
                        SetGadgetColor(#CAPTCHA_INPUT, #PB_Gadget_BackColor, RGB(255, 0, 0))
                        ProcedureReturn #True
                    EndIf
                    LoginThreadID = CreateThread(@LoginThread(), PassParameters)
                    RemoveKeyboardShortcut(0, #PB_Shortcut_Return)
            EndSelect
    EndSelect
    ProcedureReturn #True
EndProcedure

Repeat
    event = WaitWindowEvent()
Until Window_0_EventsMy(event) = #False

Procedure GetCaptchaThread(Dummy)
    GetCaptcha()
EndProcedure

Procedure GetCaptcha()
    If Not IsImage(#IMAGE_LOADING) : LoadImage(#IMAGE_LOADING, "captcha.bmp") : EndIf
    While Not IsGadget(#CAPTCHA_GADGET)
        Delay(10)
    Wend
    SetGadgetState(#CAPTCHA_GADGET, ImageID(#IMAGE_LOADING))
    StatusBarText(0, 0, "Получение каптчи...")
    curlGetCaptcha = RunProgram("curl", "-k -L -c cookie.txt -v -o captcha.jpg https://cabinet.uzonline.uz/ajaxRequest/captcha.do", GetCurrentDirectory(), #PB_Program_Wait | #PB_Program_Hide | #PB_Program_Open)
    If ProgramExitCode(curlGetCaptcha)
        Debug ProgramExitCode(curlGetCaptcha)
        Debug "Fucking Error"
        StatusBarText(0, 0, "Ошибка получения капчи!")
        ProcedureReturn
    EndIf
    LoadImage(#IMAGE_CAPTCHA, "captcha.jpg")
    SetGadgetState(#CAPTCHA_GADGET, ImageID(#IMAGE_CAPTCHA))
    StatusBarText(0, 0, "")
EndProcedure

Procedure LoginThread(Parameters)
    For i = 0 To 7
        DisableGadget(i, #DISABLE_GADGET)
    Next
    *temp.LoginStructure
    *temp = Parameters
    Debug "Func LoginThread"
    Debug "Parameters is " + Str(Parameters)
    Debug "*temp\Login$ is " + *temp\Login$
    Debug "*temp\Pass$ is " + *temp\Pass$
    Debug "*temp\Captcha$ is " + *temp\Captcha$
    If Not Login(*temp\Login$, *temp\Pass$, *temp\Captcha$)
        MessageRequester("Error","Incorrect Login/Pass/Captcha")
    EndIf
    For i = 0 To 7
        DisableGadget(i, #ENABLE_GADGET)
    Next
    Traffic(FormatDate("01.%mm.%yyyy", Date()), FormatDate("%dd.%mm.%yyyy", Date()))
    StatusBarText(0, 0, "")
EndProcedure

Procedure Login(Login$, Pass$, Captcha$)
    StatusBarText(0, 0, "Авторизация...")
    curlLogin = RunProgram("curl", "-k -L -b cookie.txt -L -o tmp -d " + Chr(34) + "state=0&login=" + Login$ + "&password=" + Pass$ + "&captch=" + Captcha$ + Chr(34) + " https://cabinet.uzonline.uz/auth.do", GetCurrentDirectory(), #PB_Program_Wait | #PB_Program_Hide | #PB_Program_Open)
    If ProgramExitCode(curlLogin)
        Debug ProgramExitCode(curlLogin)
        Debug "Error in curl Login " + Str(ProgramExitCode(curlLogin))
        ProcedureReturn #False
    EndIf
    If Not ReadFile(#FILE_CABINET, "tmp")   ; if the file could be read, we continue...
        MessageRequester("Information","Couldn't open the file!")
    EndIf
    text$ = ReadString(#FILE_CABINET, #PB_File_IgnoreEOL | #PB_UTF8)
    CloseFile(#FILE_CABINET) ; close the previously opened file
    
    If FindString(text$, "Authorization")
        If FindString(text$, "Invalid code")
            Debug "Incorrect Captcha"
        EndIf
        Debug "Error in Login"
        ProcedureReturn #False
    EndIf
    
    StatusBarText(0, 0, "Разбор данных...")
    
    CreateRegularExpression(#REGEXP_PERSONROOM, "<div class=" + Chr(34) + "left_col left" + Chr(34) + ">Account number</div>\s+<div class=" + Chr(34) + "right_col left" + Chr(34) + "><strong>(\d+)</strong></div>.+<div class=" + Chr(34) + "left_col left" + Chr(34) + ">Balance</div>\s+<div class=" + Chr(34) + "right_col left" + Chr(34) + ">\s+<strong>\s+(\d+)\s+</strong>\s+</div>.+<div class=" + Chr(34) + "left_col left" + Chr(34) + ">Traffic rest</div>\s+<div class=" + Chr(34) + "right_col left" + Chr(34) + "><strong>(\d+)</strong></div>.+<div class=" + Chr(34) + "left_col left" + Chr(34) + ">Current package service</div>\s+<div class=" + Chr(34) + "right_col left" + Chr(34) + "><strong>([^<>]+)</strong></div>", #PB_RegularExpression_NoCase | #PB_RegularExpression_DotAll)
    If ExamineRegularExpression(#REGEXP_PERSONROOM, text$)
        While NextRegularExpressionMatch(#REGEXP_PERSONROOM)
            Debug "Match: " + RegularExpressionMatchString(#REGEXP_PERSONROOM)
            Debug "Account Number " + RegularExpressionGroup(#REGEXP_PERSONROOM, 1)
            Debug "Balance " + RegularExpressionGroup(#REGEXP_PERSONROOM, 2)
            Debug "Traffic Rest " + RegularExpressionGroup(#REGEXP_PERSONROOM, 3)
            Debug "Tarrif Plan " + RegularExpressionGroup(#REGEXP_PERSONROOM, 4)
            
            SetGadgetText(#Text_6, RegularExpressionGroup(#REGEXP_PERSONROOM, 1))
            SetGadgetText(#Text_8, RegularExpressionGroup(#REGEXP_PERSONROOM, 2))
            SetGadgetText(#Text_10, RegularExpressionGroup(#REGEXP_PERSONROOM, 3))
            SetGadgetText(#Text_12, RegularExpressionGroup(#REGEXP_PERSONROOM, 4))
        Wend
    EndIf
    FreeRegularExpression(#REGEXP_PERSONROOM)
    
    
    For i = 0 To 7
        HideGadget(i, #SHOW_GADGET)
    Next
    For i = 8 To #MAX_GADGET_COUNT
        HideGadget(i, #HIDE_GADGET)
    Next
    
    ProcedureReturn #True
EndProcedure

Procedure TrafficThread(Parameters)
    *temp.TrafficStructure
    *temp = Parameters
EndProcedure

Procedure Traffic(StartDate$, EndDate$)
    StatusBarText(0, 0, "Получение данных о трафике...")
    curlTraffic = RunProgram("curl", "-k -L -b cookie.txt -L -o traffic -d " + Chr(34) + "startDate=" + StartDate$ + "&endDate=" + EndDate$ + Chr(34) + " https://cabinet.uzonline.uz/showTrafStat.do", GetCurrentDirectory(), #PB_Program_Wait | #PB_Program_Hide | #PB_Program_Open)
    If ProgramExitCode(curlTraffic)
        Debug ProgramExitCode(curlTraffic)
        Debug "Error in curl Traffic " + Str(ProgramExitCode(curlTraffic))
        ProcedureReturn #False
    EndIf
    If Not ReadFile(#FILE_CABINET, "traffic")   ; if the file could be read, we continue...
        MessageRequester("Information","Couldn't open the file!")
    EndIf
    text$ = ReadString(#FILE_CABINET, #PB_File_IgnoreEOL | #PB_UTF8)
    CloseFile(#FILE_CABINET) ; close the previously opened file
    
    If FindString(text$, "Authorization")
        Debug "Error in Login"
        ProcedureReturn #False
    EndIf
    
    StatusBarText(0, 0, "Разбор данных о трафике...")
    
    CreateRegularExpression(#REGEXP_TRAFFIC, "<th colspan=" + Chr(34) + "2" + Chr(34) + "><strong>Total</strong></th>\s+<th><strong>(\d+\.\d+)</strong></th>\s+<th><strong>(\d+\.\d+)</strong></th>", #PB_RegularExpression_NoCase | #PB_RegularExpression_DotAll)
    If ExamineRegularExpression(#REGEXP_TRAFFIC, text$)
        While NextRegularExpressionMatch(#REGEXP_TRAFFIC)
            Debug "Match: " + RegularExpressionMatchString(#REGEXP_TRAFFIC)
            Debug "Traffic Inet " + RegularExpressionGroup(#REGEXP_TRAFFIC, 1)
            Debug "Traffic Tas-Ix " + RegularExpressionGroup(#REGEXP_TRAFFIC, 2)
            
            SetGadgetText(#Text_14, RegularExpressionGroup(#REGEXP_TRAFFIC, 1))
            SetGadgetText(#Text_16, RegularExpressionGroup(#REGEXP_TRAFFIC, 2))
            SetGadgetText(#Text_18, Str(20480 - Val(RegularExpressionGroup(#REGEXP_TRAFFIC, 1))))
        Wend
    EndIf
    FreeRegularExpression(#REGEXP_TRAFFIC)
    
    ProcedureReturn #True
EndProcedure

; IDE Options = PureBasic 5.31 (Windows - x86)
; CursorPosition = 98
; FirstLine = 66
; Folding = --
; EnableAsm
; EnableUnicode
; EnableThread
; EnableXP
; CPU = 1
; EnablePurifier