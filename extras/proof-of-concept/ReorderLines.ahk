; parse simple affixes first
Loop, Read, %A_WorkingDir%\Lines.txt 
{
    IfInString, A_LoopReadLine, Simple
    {
        NumLines += 1
        LinesOrder%NumLines% := A_Index
        Lines%NumLines% := A_LoopReadLine
    }
}
; parse complex affixes last
Loop, Read, %A_WorkingDir%\Lines.txt 
{
    IfInString, A_LoopReadLine, Complex
    {
        NumLines += 1
        LinesOrder%NumLines% := A_Index
        Lines%NumLines% := A_LoopReadLine
    }
}

; output reordered lines
Loop, % NumLines
{
    CurLine := Lines%A_Index%
    OrigPos := LinesOrder%A_Index%
    ReorderedLinesAsText := ReorderedLinesAsText . A_Index . ": " . CurLine . ", original position: " . OrigPos . "`r`n"
}
msgbox, % ReorderedLinesAsText

; change lines and order as originally found
CurPos := 1
ProcessedLines := 0
While (ProcessedLines < NumLines)
{
    OrigPos := LinesOrder%CurPos%
    CurLine := Lines%CurPos%
    CurLine = %CurLine% (changed)
    If (OrigPos == (ProcessedLines+1))
    {
        ProcessedLines += 1
        ChangedLines%ProcessedLines% := CurLine
    }
    ; wrap
    If (CurPos == NumLines)
    {
        CurPos := 1
    }
    Else
    {
        CurPos += 1
    }
}

; output reordered lines
Loop, % NumLines
{
    CurLine := ChangedLines%A_Index%
    ChangedLinesAsText := ChangedLinesAsText . A_Index . ": " . CurLine . "`r`n"
}
msgbox, % ChangedLinesAsText
