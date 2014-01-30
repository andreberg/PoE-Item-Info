; Path of Exile Item Info Tooltip
;
; Version: 1.3 (hazydoc / IGN:Sadou)
;
; This script is based on the POE_iLVL_DPS-Revealer script (v1.2d) found here:
; https://www.pathofexile.com/forum/view-thread/594346
;
; Original author's comment:
; If you have any questions or comments please post them there as well. If you think you can help
; improve this project. I am looking for contributors. So Pm me if you think you can help.
;
; If you have a issue please post what version you are using.
; Reason being is that something that might be a issue might already be fixed.
; End Original author's comment
;
; The script has been added to substantially to enable the following features in addition to 
; itemlevel and weapon DPS reveal:
;
; - show total affix statistic
; - show possible min-max ranges for all affixes (!)
; - adds a system tray icon and proper system tray description tooltip
;
; The second point uses a "database" of text files which come with the script and are easy to 
; edit by non-coders. Each line in those text files has the form "max-level|value-range"
; or "max-level|<lower-bound-min>-<lower-bound-max>,<upper-bound-min>-<upper-bound-max>".
;
; Known issues:
;
;   - unique items currently do not get special treatment for min-max range reveal.
;     this is left for a future version
;
;   - stats like Accuracy Rating and Block and Stun Recovery can't be determined
;     reliably if they appear as a composite value
;     
;     Currently there is some guesstimation code in place that checks out-of-bounds values for a 
;     range and if neccessary tries another source for the affix in question.
;
;     Some background info: because the game concatenates values from multiple affix sources into
;     one final entry on the ingame tooltip there is no reliable way to work backwards from the 
;     composite value to each individual part. For example, Stun Recovery can be added as suffix if 
;     it contributes alone, but can also be a prefix if it is a composite of Stun Recovery and
;     Evasion Rating (or others). Because there is one final entry, while prefix and suffix can
;     appear at the same time and will be added together, you can't reliably reverse engineer which 
;     affix contributed what part of the composite value. This is akin to taking a random source of
;     numbers, adding them up to one value and then asking someone to work out backwards what the 
;     original source values were.
;     Similarily, in cases like boosted Stun Recovery (1) and Evasion Rating (2) on an item there is 
;     no way to tell if the prefix "+ Evasion Rating / Block and Stun Recovery" contributed to both 
;     stats at once or if the suffix "+ Block and Stun Recovery" contributed to (1) and the prefix
;     "+ Evasion Rating" cotributed to (2) or possibly a combination of both.
;
;     I have tested the tooltip on many, many items in game from my own stash and from trade chat
;     and I can say that in the overwhelming majority of cases the tooltip does indeed work correctly.
;
;     IMPORTANT: as you may know, the total amount of affixes (sine implicit mods) can be 6, of which
;     3 at most are prefixes and likewise 3 at most are suffixes. Be especially weary, then of cases
;     where this prefix/suffix limit is overcapped. It may happen that the tooltip shows 4 suffixes,
;     and 3 prefixes total. In this case the most likely explanation is that the script failed to properly
;     determine composite affixes. Composite affixes ("Comp. Prefix" or "Comp. Suffix" in the tooltip)
;     are two affix lines on the ingame tooltip that together form one single composite affix. 
;
;   - I do not know which affixes are affected by +% Item Quality. Currently I have functions in place 
;     that can boost a range or a single value to adjust for Item Quality but currently these aren't used
;     much. Partially this is also because it is not easy to tell if out-of-bounds cases are the result
;     of faulty input data (I initially pulled data from the PoE mods compendium but later made the PoE
;     homepage the authoritative source overruling data from other sources) or of other unreckognized and
;     unhandled entities or systems.
;
; Todo:
;
;   - handle ranges for implicit mods
;   - handle unique items specially
;
; Notes:
;
;   - Global values marked with an inline comment "d" are globals for debugging so they can be easily 
;     (re-)enabled using global search and replace. Marking variables as global means they will show 
;     up in AHK's Variables and contents view of the script.
;   
; Needs AutoHotKey v1.0.45 or later
;
; Original credits:
;
;   mcpower - for the base iLVL display of the script 5months ago before Immo.
;   Immo - for the base iLVL display of the script.(Which was taken from mcpower.)
;   olop4444 - for helping me figure out the calculations for Q20 items.
;   Aeons - for a rewrite and fancy tooltips.
;   kongyuyu - for base item level display.
;   Fayted - for testing the script.
;

; do nothing if Path of Exile isn't the foremost window
#IfWinActive, Path of Exile ahk_class Direct3DWindowClass
#SingleInstance force
#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
#Persistent ; Stay open in background
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
StringCaseSense, On ; Match strings with case.

; OPTIONS

DisplayBaseLevel = 1         ; Enabled by default change to 0 to disable

ShowAffixTotals  = 1         ; Show total affix statistics
ShowAffixDetails = 1         ; Show detailed info about affixes
ShowAffixLevel = 0           ; Show item level of the affix 
ShowAffixBracket = 1         ; Show range for the affix' bracket as is on the item
ShowAffixMaxPossible = 1     ; Show max possible bracket for an affix based on the item's item level

MaxSpanStartingFromFirst = 1 ; When showing max possible, don't just show the highest possible affix bracket 
                             ; but construct a pseudo range which spans the lower bound of the lowest possible 
                             ; bracket to the upper bound of the highest possible one. 
                             ;
                             ; This is usually what you want to see when evaluating an item's worth. The exception 
                             ; being when you want to reroll an affix to the highest possible value within it's
                             ; current bracket - then you need to see the affix range that is actually on the item 
                             ; right now.

CompactDoubleRanges = 1      ; Show double ranges as "1-172" instead of "1-8 to 160-172"
CompactAffixTypes = 1        ; Use compact affix type designations: Suffix = S, Prefix = P, Comp. Suffix = CS, Comp. Prefix = CP

MirrorAffixLines = 1         ; Show a copy of the affix line in question when showing affix details. 
                             ; For example, would display "Prefix, 5-250" instead of "+246 to Accuracy Rating, Prefix, 5-250". 
                             ; Since the affixes are processed in order one can attribute which is which to the ordering of 
                             ; the lines in the tooltip to the item data in game.

MirrorLineFieldWidth = 18    ; Mirrored affix line width. Set to a number above 0 to truncate (or pad) to this many characters. 
                             ; Appends AffixDetailEllipsis when truncating.
ValueRangeFieldWidth = 7     ; Width of field that displays the affix' value range(s). Set to a number larger than 0 to truncate (or pad) to this many characters. 

AffixDetailDelimiter := " "  ; Delimiter for each line's affix detail list
AffixDetailEllipsis := "…"   ; Make sure you are using the version of this script that matches the AHK version you are using it with. 
                             ; e.g. use the Unicode version for AHK Unicode and ANSI otherwise. See 

; Pixels mouse must move to auto-dismiss tooltip
MouseMoveThreshold := 40

; Set this to 1 if you want to have the tooltip disappear after the time frame set below.
; Otherwise you will have to move the mouse by 5 pixels for the tip to disappear.
UseTooltipTimeout = 0

;How many ticks to wait before removing tooltip. 1 tick = 100ms. Example, 50 ticks = 5secends, 75 Ticks = 7.5Secends
ToolTipTimeoutTicks := 150

; Font size for the tooltip, leave empty for default
FontSize := 11

; OPTIONS END

; Menu tooltip
Menu, tray, Tip, Path of Exile Item Info

; Windows system tray icon
; possible values: poe.ico, poe-bw.ico, poe-web.ico, info.ico
Menu, tray, Icon, data\poe-bw.ico
 
If (A_AhkVersion <= "1.0.45")
{
    msgbox, You need AutoHotkey v1.0.45 or later to run this script. `n`nPlease go to http://ahkscript.org/download to download a recent version.
    exit
}

; Create font for later use
FixedFont := CreateFont()
 
; Creates a font for later use
CreateFont()
{
    Global FontSize
    Options :=
    If (!(FontSize = "")) 
    {
        Options = s%FontSize%
    }
    Gui Font, %Options%, Courier New
    Gui Font, %Options%, Consolas
    Gui Add, Text, HwndHidden, 
    SendMessage, 0x31,,,, ahk_id %Hidden%
    return ErrorLevel
}
 
; Sets the font for a created ahk tooltip
SetFont(Font)
{
    SendMessage, 0x30, Font, 1,, ahk_class tooltips_class32 ahk_exe autohotkey.exe
}
 
; Parse elemental damage
ParseDamage(String, DmgType, ByRef DmgLo, ByRef DmgHi)
{
    IfInString, String, %DmgType% Damage 
    {
        IfInString, String, Converted to or IfInString, String, taken as
            Return
        IfNotInString, String, increased 
        {
            StringSplit, Arr, String, %A_Space%
            StringSplit, Arr, Arr2, -
            DmgLo := Arr1
            DmgHi := Arr2
        }
    }
}

; Added fuction for reading itemlist.txt added fuction by kongyuyu
if (DisplayBaseLevel = 1) 
{
    ItemListArray = 0
    Loop, Read, %A_WorkingDir%\data\ItemList.txt 
    {  
        ; This loop retrieves each line from the file, one at a time.
        ItemListArray += 1  ; Keep track of how many items are in the array.
        StringSplit, NameLevel, A_LoopReadLine, |,
        Array%ItemListArray%1 := NameLevel1  ; Store this line in the next array element.
        Array%ItemListArray%2 := NameLevel2
    }
}

; Function that check item name against the array
; Then add base lvl to the ItemName
CheckBaseLevel(ByRef ItemName)
{
    Global
    Loop %ItemListArray% {
        element := Array%A_Index%1
        IfInString, ItemName, %element% 
        {
            BaseLevel := "   " . Array%A_Index%2
            StringRight, BaseLevel, BaseLevel, 3
            ItemName := ItemName . "Base lvl:  " . BaseLevel . "`n"
            Break
        }
    }
}

CheckRarityLevel(RarityString)
{
    IfInString, RarityString, Normal
        return 1
    IfInString, RarityString, Magic
        return 2
    IfInString, RarityString, Rare
        return 3
    IfInString, RarityString, Unique
        return 4
    return 0 ; unknown rarity. shouldn't happen!
}

ParseItemType(ItemDataStats, ItemDataNamePlate, ByRef BaseType, ByRef SubType, ByRef GripType)
{
    ; Grip type only matters for weapons at this point. For all others it will be 'None'.
    GripType = None

    ; Check stats section first as weapons usually have their sub type as first line
    Loop, Parse, ItemDataStats, `n, `r
    {
        IfInString, A_LoopField, One Handed Axe
        {
            BaseType = Weapon
            SubType = Axe
            GripType = 1H
            return
        }
        IfInString, A_LoopField, Two Handed Axe
        {
            BaseType = Weapon
            SubType = Axe
            GripType = 2H
            return
        }
        IfInString, A_LoopField, One Handed Mace
        {
            BaseType = Weapon
            SubType = Mace
            GripType = 1H
            return
        }
        IfInString, A_LoopField, Two Handed Mace
        {
            BaseType = Weapon
            SubType = Mace
            GripType = 2H
            return
        }
        IfInString, A_LoopField, Sceptre
        {
            BaseType = Weapon
            SubType = Sceptre
            GripType = 1H
            return
        }
        IfInString, A_LoopField, Staff
        {
            BaseType = Weapon
            SubType = Staff
            GripType = 2H
            return
        }
        IfInString, A_LoopField, One Handed Sword
        {
            BaseType = Weapon
            SubType = Sword
            GripType = 1H
            return
        }
        IfInString, A_LoopField, Two Handed Sword
        {
            BaseType = Weapon
            SubType = Sword
            GripType = 2H
            return
        }
        IfInString, A_LoopField, Dagger
        {
            BaseType = Weapon
            SubType = Dagger
            GripType = 1H
            return
        }
        IfInString, A_LoopField, Claw
        {
            BaseType = Weapon
            SubType = Claw
            GripType = 1H
            return
        }
        IfInString, A_LoopField, Bow
        {
            ; Yeah, I know one handed bow doesn't make much sense but that's how 
            ; the game classifies it (mainly because you can equip a quiver in 2nd hand slot)
            BaseType = Weapon
            SubType = Bow
            GripType = 1H
            return
        }
        IfInString, A_LoopField, Wand
        {
            BaseType = Weapon
            SubType = Wand
            GripType = 1H
            return
        }
    }

    ; Check name plate section 
    Loop, Parse, ItemDataNamePlate, `n, `r
    {
        ; Belts, Amulets, Rings, Quivers, Flasks
        IfInString, A_LoopField, Belt
        {
            BaseType = Item
            SubType = Belt
            return
        }
        IfInString, A_LoopField, Amulet
        {
            BaseType = Item
            SubType = Amulet
            return
        }
        IfInString, A_LoopField, Ring
        {
            BaseType = Item
            SubType = Ring
            return
        }
        IfInString, A_LoopField, Quiver
        {
            BaseType = Item
            SubType = Quiver
            return
        }
        IfInString, A_LoopField, Flask
        {
            BaseType = Item
            SubType = Flask
            return
        }

        ; Shields 
        IfInString, A_LoopField, Shield
        {
            BaseType = Armour
            SubType = Shield
            return
        }
        IfInString, A_LoopField, Buckler
        {
            BaseType = Armour
            SubType = Shield
            return
        }
        IfInString, A_LoopField, Bundle
        {
            BaseType = Armour
            SubType = Shield
            return
        }
        IfInString, A_LoopField, Gloves
        {
            BaseType = Armour
            SubType = Gloves
            return
        }
        IfInString, A_LoopField, Mitts
        {
            BaseType = Armour
            SubType = Gloves
            return
        }
        IfInString, A_LoopField, Gauntlets
        {
            BaseType = Armour
            SubType = Gloves
            return
        }

        ; Helmets
        IfInString, A_LoopField, Helmet
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Helm
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Hat
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Mask
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Hood
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Pelt
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Circlet
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Sallet
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Burgonet
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Bascinet
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Crown
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Cage
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
        IfInString, A_LoopField, Tricorne
        {
            BaseType = Armour
            SubType = Helmet
            return
        }
    }

    ; TODO: need a way to determine sub type for armour
    BaseType = Armour
    SubType = Armour
}

GetClipboardContents(DropNewlines = False)
{
    Result =
    If Not DropNewlines
    {
        Loop, Parse, Clipboard, `n, `r
        {
            Result := Result . A_LoopField . "`r`n"
        }
    }
    Else
    {   
        Loop, Parse, Clipboard, `n, `r
        {
            Result := Result . A_LoopField
        }
    }
    return Result
}

SetClipboardContents(String)
{
    Clipboard := String
}

; Currently unused
SplitString(StrInput, StrDelimiter)
{
    TempDelim := "``"
    ;Global TempResult
    StringReplace, TempResult, StrInput, %StrDelimiter%, %TempDelim%, All
    ;Global Parts0
    StringSplit, Parts, TempResult, %TempDelim%
    return Parts
}

; Look up just the most applicable bracket for an affix.
; Most applicable means Value is between bounds of bracket range 
; OR highest entry possible given the item level
; returns: "#-#" format range
; If Value is unspecified ("") return the max possible bracket 
; based on item level
LookupAffixBracket(Filename, ItemLevel, Value="", ByRef BracketLevel="")
{
    AffixLevel := 0
    AffixDataIndex := 0
    If (Not Value == "")
    {
        ValueLo := Value             ; value from ingame tooltip
        ValueHi := Value             ; for single values (which most of them are) ValueLo == ValueHi
        ParseRange(Value, ValueHi, ValueLo)
    }
    LookupIsDoubleRange := False ; for affixes like "Adds +# ... Damage" which have a lower AND an upper bound range
    BracketRange := "n/a"
    Loop, Read, %A_WorkingDir%\%Filename%
    {  
        AffixDataIndex += 1
        StringSplit, AffixDataParts, A_LoopReadLine, |,
        RangeLevel := AffixDataParts1
        RangeValues := AffixDataParts2
        If (RangeLevel > ItemLevel)
        {
            Break
        }
        IfInString, RangeValues, `,
        {
            LookupIsDoubleRange := True
        }
        If (LookupIsDoubleRange)
        {
            ; example lines from txt file database for double range lookups:
            ;  3|1,14-15
            ; 13|1-3,35-37
            StringSplit, DoubleRangeParts, RangeValues, `,
            LB := DoubleRangeParts%DoubleRangeParts%1
            UB := DoubleRangeParts%DoubleRangeParts%2
            ; default case: lower bound is single value: #
            ; see level 3 case in example lines above
            LBMin := LB
            LBMax := LB
            UBMin := UB
            UBMax := UB
            IfInString, LB, -
            {
                ; lower bound is a range: #-#
                ParseRange(LB, LBMax, LBMin)
            }
            IfInString, UB, -
            {
                ParseRange(UB, UBMax, UBMin)
            }
            LBPart = %LBMin%
            UBPart = %UBMax%
            ; record bracket range if it is withing bounds of the text file entry
            If (Value == "" or (((ValueLo >= LBMin) and (ValueLo <= LBMax)) and ((ValueHi >= UBMin) and (ValueHi <= UBMax))))
            {
                BracketRange = %LBPart%-%UBPart%
                AffixLevel = %RangeLevel%
            }
        }
        Else
        {
            ParseRange(RangeValues, HiVal, LoVal)
            ; record bracket range if it is withing bounds of the text file entry
            If (Value == "" or ((ValueLo >= LoVal) and (ValueHi <= HiVal)))
            {
                BracketRange = %LoVal%-%HiVal%
                AffixLevel = %RangeLevel%
            }
        }
    }
    return BracketRange
}

; Look up complete data for an affix. Depending on settings flags 
; this may include many things, and will return a string used for
; end user display rather than further calculations. 
; Use LookupAffixBracket if you need a range format to do calculations with.
LookupAffixData(Filename, ItemLevel, Value, ByRef BracketLevel="")
{
    Global MaxLevel
    Global ShowAffixLevel
    Global ShowAffixBracket
    Global ShowAffixMaxPossible
    Global CompactDoubleRanges
    Global MaxSpanStartingFromFirst
    Global ValueRangeFieldWidth
    MaxLevel := 0
    AffixLevel := 0
    AffixDataIndex := 0
    ValueLo := Value             ; value from ingame tooltip
    ValueHi := Value             ; for single values (which most of them are) ValueLo == ValueHi
    ValueIsMinMax := False       ; treat Value as min/max units (#-#) or as single unit (#)
    LookupIsDoubleRange := False ; for affixes like "Adds +# ... Damage" which have a lower AND an upper bound range
    FirstRangeValues =
    BracketRange := "n/a"
    MaxRange =
    FinalRange = 
    MaxLevel := 1
    RangeLevel := 1
    IfInString, Value, -
    {
        ParseRange(Value, ValueHi, ValueLo)
        ValueIsMinMax := True
    }
    Loop, Read, %A_WorkingDir%\%Filename%
    {  
        AffixDataIndex += 1
        StringSplit, AffixDataParts, A_LoopReadLine, |,
        RangeValues := AffixDataParts2
        RangeLevel := AffixDataParts1
        If (AffixDataIndex == 1)
        {
            FirstRangeValues := RangeValues
        }
        If (RangeLevel > ItemLevel)
        {
            Break
        }
        MaxLevel := RangeLevel
        IfInString, RangeValues, `,
        {
            LookupIsDoubleRange := True
        }
        If (LookupIsDoubleRange)
        {
;            ; variables for min/max double ranges, like in the "Adds +# ... Damage" case
;            Global LBMin     ; (L)ower (B)ound minium value
;            Global LBMax     ; (L)ower (B)ound maximum value
;            GLobal UBMin     ; (U)pper (B)ound minimum value
;            GLobal UBMax     ; (U)pper (B)ound maximum value
;            ; same, just for the first range's values
;            Global FRLBMin   
;            Global FRLBMax   
;            Global FRUBMin   
;            Global FRUBMax   
            ; example lines from txt file database for double range lookups:
            ;  3|1,14-15
            ; 13|1-3,35-37
            StringSplit, DoubleRangeParts, RangeValues, `,
            LB := DoubleRangeParts%DoubleRangeParts%1
            UB := DoubleRangeParts%DoubleRangeParts%2
            ; default case: lower bound is single value: #
            ; see level 3 case in example lines above
            LBMin := LB
            LBMax := LB
            UBMin := UB
            UBMax := UB
            IfInString, LB, -
            {
                ; lower bound is a range: #-#
                ParseRange(LB, LBMax, LBMin)
            }
            IfInString, UB, -
            {
                ParseRange(UB, UBMax, UBMin)
            }
            If (AffixDataIndex == 1)
            {
                StringSplit, FirstDoubleRangeParts, FirstRangeValues, `,
                FRLB := FirstDoubleRangeParts%FirstDoubleRangeParts%1
                FRUB := FirstDoubleRangeParts%FirstDoubleRangeParts%2
                ParseRange(FRUB, FRUBMax, FRUBMin)
                ParseRange(FRLB, FRLBMax, FRLBMin)
            }
            If ((LBMin == LBMax) or CompactDoubleRanges) 
            {
                LBPart = %LBMin%
            }
            Else
            {
                LBPart = %LBMin%-%LBMax%
            }
            If ((UBMin == UBMax) or CompactDoubleRanges) 
            {
                UBPart = %UBMax%
            }
            Else
            {
                UBPart = %UBMin%-%UBMax%
            }
            If ((FRLBMin == FRLBMax) or CompactDoubleRanges)
            {
                FRLBPart = %FRLBMin%
            }
            Else
            {
                FRLBPart = %FRLBMin%-%FRLBMax%
            }
            If (CompactDoubleRanges)
            {
                MiddlePart := "-"
            }
            Else
            {
                MiddlePart := " to "
            }
            ; record bracket range if it is withing bounds of the text file entry
            If (((ValueLo >= LBMin) and (ValueLo <= LBMax)) and ((ValueHi >= UBMin) and (ValueHi <= UBMax)))
            {
                ;msgbox, Value: %Value%`, LBPart: %LBPart%`, UBPart: %UBPart%
                BracketRange = %LBPart%%MiddlePart%%UBPart%
                AffixLevel = %MaxLevel%
                ;msgbox, BracketRange: %BracketRange%
            }
            ; record max possible range regardless of within bounds
            If (MaxSpanStartingFromFirst)
            {
                MaxRange = %FRLBPart%%MiddlePart%%UBPart%
            }
            Else
            {
                MaxRange = %LBPart%%MiddlePart%%UBPart%
            }
        }
        Else
        {
            If (AffixDataIndex = 1)
            {
                ParseRange(FirstRangeValues, FRHiVal, FRLoVal)
            }
            ParseRange(RangeValues, HiVal, LoVal)
            ; record bracket range if it is within bounds of the text file entry
            If ((ValueLo >= LoVal) and (ValueHi <= HiVal))
            {
                If (LoVal = HiVal)
                {
                    BracketRange = %LoVal%
                }
                Else
                {
                    BracketRange = %LoVal%-%HiVal%
                }
                AffixLevel = %MaxLevel%
            }
            ; record max possible range regardless of within bounds
            If (MaxSpanStartingFromFirst)
            {
                MaxRange = %FRLoVal%-%HiVal%
            }
            Else
            {
                MaxRange = %LoVal%-%HiVal%
            }
        }
;        msgbox, Filename: %Filename%`n ValueLo: %ValueLo%`, ValueHi: %ValueHi%`n LoVal: %LoVal%`, HiVal: %HiVal%
    }
   BracketLevel := AffixLevel
   If (ShowAffixBracket)
    {
        FinalRange := BracketRange
        If (ValueRangeFieldWidth > 0)
        {
            FinalRange := StrPad(FinalRange, ValueRangeFieldWidth, "left")
        }
        If (ShowAffixLevel)
        {
            FinalRange := FinalRange . " " . "(" . AffixLevel . ")" . ", "
        }
        Else
        {
            Global AffixDetailDelimiter
            FinalRange := FinalRange . AffixDetailDelimiter
        }
    }
    If (ShowAffixMaxPossible)
    {

        If (ValueRangeFieldWidth > 0)
        {
            MaxRange := StrPad(MaxRange, ValueRangeFieldWidth, "left")
        }
        FinalRange := FinalRange . MaxRange
        If (ShowAffixLevel)
        {
            FinalRange := FinalRange . " " . "(" . MaxLevel . ")"
        }
    }
    ;msgbox, FinalRange: %FinalRange%
    return FinalRange
}

ParseRarity(ItemData_NamePlate)
{
    Global RarityParts0
    Loop, Parse, ItemData_NamePlate, `n, `r
    {
        IfInString, A_LoopField, Rarity:
        {
            StringSplit, RarityParts, A_LoopField, %A_Space%
            Break
        }
    }
    return RarityParts%RarityParts%2
}

ParseQuality(ItemDataNamePlate)
{
    ItemQuality := 0
    Loop, Parse, ItemDataNamePlate, `n, `r
    {
        If (StrLen(A_LoopField) = 0)
        {
            Break
        }
        IfInString, A_LoopField, Unidentified
        {
            Break
        }
        IfInString, A_LoopField, Quality:
        {
            ItemQuality := RegExReplace(A_LoopField, "Quality: \+(\d+)% .*", "$1")
            Break
        }
    }
    return ItemQuality
}

ParseAugmentations(ItemDataChunk, ByRef AffixCSVList)
{
    Global CurAugment
    CurAugment := ItemDataChunk
    Loop, Parse, ItemDataChunk, `n, `r
    {
        CurAugment := A_LoopField
        IfInString, A_LoopField, Requirements:
        {
            Break
        }
        IfInString, A_LoopField, (augmented)
        {
            StringSplit, LineParts, A_LoopField, :
            AffixCSVList := AffixCSVList . "'"  . LineParts%LineParts%1 . "'"
            AffixCSVList := AffixCSVList . ", "
        }
    }
    AffixCSVList := SubStr(AffixCSVList, 1, -2)
}

ParseRequirements(ItemDataChunk, ByRef Level, ByRef Attributes, ByRef Values="")
{
    IfNotInString, ItemDataChunk, Requirements
    {
        return
    }
    Attr =
    AttrValues =
    Delim := ","
    DelimLen := StrLen(Delim)
    Loop, Parse, ItemDataChunk, `n, `r
    {    
        If StrLen(A_LoopField) = 0
        {
            Break ; not interested in blank lines
        }
        IfInString, A_LoopField, Str
        {
            Attr := Attr . "Str" . Delim
            AttrValues := AttrValues . GetColonValue(A_LoopField) . Delim
        }
        IfInString, A_LoopField, Dex
        {
            Attr := Attr . "Dex" . Delim
            AttrValues := AttrValues . GetColonValue(A_LoopField) . Delim
        }
        IfInString, A_LoopField, Int
        {
            Attr := Attr . "Int" . Delim
            AttrValues := AttrValues . GetColonValue(A_LoopField) . Delim
        }
        IfInString, A_LoopField, Level
        {
            Level := GetColonValue(A_LoopField)
        }
    }
    ; chop off last Delim
    If (SubStr(Attr, -(DelimLen-1)) == Delim)
    {
        Attr := SubStr(Attr, 1, -(DelimLen))
    }
    If (SubStr(AttrValues, -(DelimLen-1)) == Delim)
    {
        AttrValues := SubStr(AttrValues, 1, -(DelimLen))
    }
    Attributes := Attr
    Values := AttrValues
}

; parses #low-#high and sets Hi to #high and Lo to #low
; if RangeChunk is just a single value (#) it will set both
; Hi and Lo to this single value (effectively making the range 1-1 if # was 1)
ParseRange(RangeChunk, ByRef Hi, ByRef Lo)
{
    IfInString, RangeChunk, -
    {
        StringSplit, RangeParts, RangeChunk, -
        Lo := RegExReplace(RangeParts1, "(\d+?)", "$1")
        Hi := RegExReplace(RangeParts2, "(\d+?)", "$1")
    }
    Else
    {
        Hi := RangeChunk
        Lo := RangeChunk
    }
}

ParseItemLevel(ItemData)
{
    Result =
    Loop, Parse, ItemData, `n, `r
    {
        If StrLen(A_LoopField) = 0
        {
            Break
        }
        IfInString, A_LoopField, Itemlevel:
        {
            StringSplit, ItemLevelParts, A_LoopField, %A_Space%
            Result := ItemLevelParts2
            Break
        }
    }
    return Result
}

StrMult(Char, Times)
{
    Result =
    Loop, %Times%
    {
        Result := Result . Char
    }
    return Result
}

StrTrimSpaceLeft(String)
{
    return RegExReplace(String, " *(.+?)", "$1")
}

StrTrimSpaceRight(String)
{
    return RegExReplace(String, "(.+?) *$", "$1")
}

StrTrimSpace(String)
{
    return RegExReplace(String, " *(.+?) *", "$1")
}

StrPad(String, Length, Side="right", PadChar=" ")
{
;    Result := String
    Len := StrLen(String)
    AddLen := Length-Len
    Pad := StrMult(PadChar, AddLen)
    If (Side == "right")
    {
        Result := String . Pad
    }
    Else
    {
        Result := Pad . String
    }
    return Result
}

AppendAffixInfo(AffixLine, AffixType, ValueRange, ByRef AffixInfo)
{
    Global AffixDetailDelimiter
    Global AffixDetailEllipsis
    Global MirrorAffixLines
    Global MirrorLineFieldWidth
    Global ValueRangeFieldWidth
    Global CompactAffixTypes
    Delim := AffixDetailDelimiter
    Ellipsis := AffixDetailEllipsis
    Line =
    If (MirrorAffixLines = 1)
    {
        If (MirrorLineFieldWidth > 0)
        {
            If(StrLen(AffixLine) > MirrorLineFieldWidth)
            {   
                AffixLine := StrTrimSpaceRight(SubStr(AffixLine, 1, MirrorLineFieldWidth)) . Ellipsis
            }
            AffixLine := StrPad(AffixLine, MirrorLineFieldWidth + StrLen(Ellipsis))
        }
        Line := AffixLine . Delim
    }
    If (ValueRangeFieldWidth > 0)
    {
        ValueRange := StrPad(ValueRange, ValueRangeFieldWidth, "left")
    }
    If (CompactAffixTypes > 0)
    {
        AffixType := RegExReplace(AffixType, "Comp\. ", "C")
        AffixType := RegExReplace(AffixType, "Suffix", "S")
        AffixType := RegExReplace(AffixType, "Prefix", "P")
    }
    Line := Line . ValueRange . Delim . AffixType
    AffixInfo := AffixInfo . "`n" . Line
}

; Same as AdjustRangeForQuality, except that Value is just
; a single value and not a range.
AdjustValueForQuality(Value, ItemQuality, Direction="up")
{
    If (ItemQuality == 0)
        return Value
    Divisor := ItemQuality / 100
    If (Direction == "up")
    {
        Result := Round(Value + (Value * Divisor))
    }
    Else
    {
        Result := Round(Value - (Value * Divisor))
    }
    return Result
}

; Adjust an affix' range for +% Quality on an item.
; For example: given the range 10-20 and item quality +15%
; the result would be 11.5-23 which is currently rounded up
; to 12-23. Note that Direction does not play a part in rounding
; rather it controls if adjusting up towards quality increase or
; down from quality increase (to get the original value back)
AdjustRangeForQuality(ValueRange, ItemQuality, Direction="up")
{
    If (ItemQuality = 0)
    {
        return ValueRange
    }
    VRHi := 0
    VRLo := 0
    ParseRange(ValueRange, VRHi, VRLo)
    Divisor := ItemQuality / 100
    If (Direction == "up")
    {
        VRHi := Round(VRHi + (VRHi * Divisor))
        VRLo := Round(VRLo + (VRLo * Divisor))
    }
    Else
    {
        VRHi := Round(VRHi - (VRHi * Divisor))
        VRLo := Round(VRLo - (VRLo * Divisor))
    }
    If (VRLo == VRHi)
    {
        ValueRange = %VRLo%
    }
    Else
    {
        ValueRange = %VRLo%-%VRHi%
    }
    return ValueRange
}

IsOutOfBounds(ValueRange, ActualValue)
{
    VHi := 0
    VLo := 0
    ParseRange(ValueRange, VHi, VLo)
    IfInString, ActualValue, -
    {
        AVHi := 0
        AVLo := 0
        ParseRange(ActualValue, AVHi, AVLo)
        If ((AVLo < VLo) or (AVHi > VHi))
        {
            return True
        }
    }
    Else
    {
        If ((ActualValue < VLo) or (ActualValue > VHi))
        {
            return True
        }
    }
    return False
}

; Get actual value from a line of the ingame tooltip as a number
; that can be used in calculations.
GetActualValue(ActualValueLine)
{
    Result := RegExReplace(ActualValueLine, ".*?\+?(\d+(?:-\d+|\.\d+)?).*", "$1")
    return Result
}

; Get value from a color line, e.g. given the line "Level: 57", returns the number 57
GetColonValue(Line)
{
    IfInString, Line, :
    {
        StringSplit, LineParts, Line, :
        Result := StrTrimSpace(LineParts%LineParts%2)
        return Result
    }
}

RangeAverage(Range)
{
    If (Range = 0 or Range = "0" or Range = "0-0")
    {
        return 0
    }
    RHi := 0
    RLo := 0
    ParseRange(Range, RHi, RLo)
    return Floor((RHi+RLo)/2)
}

AddRange(Range1, Range2)
{
    R1Hi := 0
    R1Lo := 0
    R2Hi := 0
    R2Lo := 0
    ParseRange(Range1, R1Hi, R1Lo)
    ParseRange(Range2, R2Hi, R2Lo)
    FinalHi := R1Hi + R2Hi
    FinalLo := R1Lo + R2Lo
    FinalRange = %FinalLo%-%FinalHi%
    return FinalRange
}

ParseAffixes(ItemDataChunk, ItemLevel, ItemQuality, ImplicitMods, AugmentedStats, ByRef AffixInfo, ByRef NumPrefixes, ByRef NumSuffixes, ByRef NumExtras)
{
    Global ItemBaseType
    Global ItemSubType
    Global ItemGripType
    
    ; Composition flags
    ; these are required for later descision making when guesstimating
    ; value sources from same type affixes
    HasIIQ := False
    HasIncrEvasion := False
    HasIncrEnergyShield := False
    HasHybridDefences := False
    HasIncrLightRadius := False
    HasIncrAccuracyRating := False
    HasIncrPhysDmg := False
    HasToAccuracyRating := False
    HasStunRecovery := False
    HasSpellDamage := False
    HasMaxMana := False

    ; max mana already accounted for in case of composite prefix+prefix "Spell Damage / Max Mana" + "Max Mana"
    MaxManaPartial =

    ; Accuracy Rating already accounted for in case of 
    ;   composite prefix + composite suffix: "increased Physical Damage / to Accuracy Rating" + "to Accuracy Rating / Light Radius"
    ;   composite prefix + suffix: "increased Physical Damage / to Accuracy Rating" + "to Accuracy Rating"
    ARPartial =

    ; indicates a composite stun recovery affix if true
    CompStunRecovery := False

    ; estimate indicator, marks end user display values that were guesstimated
    EstInd := " * "

    ; Pre-pass to determine composition flags
    Loop, Parse, ItemDataChunk, `n, `r
    {    
        If StrLen(A_LoopField) = 0
        {
            Break ; not interested in blank lines
        }
        IfInString, ItemDataChunk, Unidentified
        {
            Break ; not interested in unidentified items
        }
        IfInString, A_LoopField, increased Light Radius
        {
            HasIncrLightRadius := True
            Continue
        }
        IfInString, A_LoopField, increased Quantity
        {
            HasIIQ := True
            Continue
        }
        IfInString, A_LoopField, increased Physical Damage
        {
            HasIncrPhysDmg := True
            Continue
        }
        IfInString, A_LoopField, increased Accuracy Rating
        {
            HasIncrAccuracyRating := True
            Continue
        }
        IfInString, A_LoopField, to Accuracy Rating
        {
            HasToAccuracyRating := True
            Continue
        }
        IfInString, A_LoopField, increased Armour and Evasion
        {
            HasHybridDefences := True
            Continue
        }
        IfInString, A_LoopField, increased Armour and Energy Shield
        {
            HasHybridDefences := True
            Continue
        }
        IfInString, A_LoopField, increased Evasion and Energy Shield
        {
            HasHybridDefences := True
            Continue
        }
        IfInString, A_LoopField, increased Evasion Rating
        {
            HasIncrEvasion := True
            Continue
        }
        IfInString, A_LoopField, increased Energy Shield
        {
            HasIncrEnergyShield := True
            Continue
        }
        IfInString, A_LoopField, increased Block and Stun Recovery
        {
            HasStunRecovery := True
            Continue
        }
        IfInString, A_LoopField, increased Spell Damage
        {
            HasSpellDamage := True
            Continue
        }
        IfInString, A_LoopField, to maximum Mana
        {
            HasMaxMana := True
            Continue
        }
    }

    Loop, Parse, ItemDataChunk, `n, `r
    {
        If StrLen(A_LoopField) = 0
        {
            Break ; not interested in blank lines
        }
        IfInString, ItemDataChunk, Unidentified
        {
            Break ; not interested in unidentified items
        }
        
        ; Note: yes, this superlong IfInString structure sucks
        ; but hey, AHK sucks as a scripting language, so bite me.
        ; But in all seriousness, the incrementing parts could be
        ; covered with one label+goto per affix type but I decided
        ; not to because the if bodies are actually placeholders 
        ; for a system that looks up max and min values possible
        ; per affix from a collection of text files. The latter is 
        ; a TODO for a future version of the script though.
        
        Global CurrValue ; d
        CurrValue := GetActualValue(A_LoopField)

        ; Suffixes

        IfInString, A_LoopField, increased Attack Speed
        {
            NumSuffixes += 1
            If (ItemBaseType == "Weapon") ; ItemBaseType is Global!
            {
                ValueRange := LookupAffixData("data\AttackSpeed_Weapons.txt", ItemLevel, CurrValue)
            }
            Else
            {
                ValueRange := LookupAffixData("data\AttackSpeed_ArmourAndItems.txt", ItemLevel, CurrValue)
            }
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Accuracy Rating
        {
            AffixType := "Comp. Suffix"
            ValueRange := LookupAffixData("data\IncrAccuracyRating_LightRadius_A.txt", ItemLevel, CurrValue)
            NumSuffixes += 1
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to all Attributes 
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToAllAttributes.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Strength
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToStrength.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Intelligence
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToIntelligence.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Dexterity
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToDexterity.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Cast Speed
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\CastSpeed.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        ; This needs to come before "Critical Strike Chance" !
        IfInString, A_LoopField, increased Critical Strike Chance for Spells
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\SpellCritChance.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Critical Strike Chance
        {
            If (ItemSubType == "Quiver" or ItemSubType == "Amulet")
            {
                ValueRange := LookupAffixData("data\CritChance_AmuletsAndQuivers.txt", ItemLevel, CurrValue)
            }
            Else
            {
                ValueRange := LookupAffixData("data\CritChance_Weapons.txt", ItemLevel, CurrValue)
            }
            NumSuffixes += 1
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Critical Strike Multiplier
        {
            If (ItemSubType == "Quiver" or ItemSubType == "Amulet")
            {
                ValueRange := LookupAffixData("data\CritMultiplier_AmuletsAndQuivers.txt", ItemLevel, CurrValue)
            }
            Else
            {
                ValueRange := LookupAffixData("data\CritMultiplier_Weapons.txt", ItemLevel, CurrValue)
            }
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            NumSuffixes += 1
            Continue
        }
        IfInString, A_LoopField, increased Fire Damage
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\IncrFireDamage.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Cold Damage
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\IncrColdDamage.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Lightning Damage
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\IncrLightningDamage.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Light Radius
        {
            ValueRange := LookupAffixData("data\IncrAccuracyRating_LightRadius_B.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Comp. Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Block chance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\BlockChance.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        
        ; Flask effects (on belts)
        IfInString, A_LoopField, reduced Flask Charges used
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FlaskChargesUsed.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Flask Charges gained
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FlaskChargesGained.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Flask effect duration
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FlaskDuration.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        
        ; Flasks Suffixes
        ; only applicable to *drumroll* ... flasks
        IfInString, A_LoopField, Dispels
        {
            ; covers Shock, Burning and Frozen and Chilled
            NumSuffixes += 1
            Continue
        }
        IfInString, A_LoopField, Removes Bleeding
        {
            NumSuffixes += 1
            Continue
        }
        IfInString, A_LoopField, Removes Curses on use
        {
            NumSuffixes += 1
            Continue
        }
        IfInString, A_LoopField, during flask effect
        {
            NumSuffixes += 1
            Continue
        }
        IfInString, A_LoopField, Adds Knockback
        {
            NumSuffixes += 1
            Continue
        }
        IfInString, A_LoopField, Life Recovery to Minions
        {
            NumSuffixes += 1
            Continue
        }
        ; END Flask Suffixes
        
        IfInString, A_LoopField, increased Quantity
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\IIQ.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Life gained on Kill
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LifeOnKill.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Life gained for each enemy hit by your Attacks
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LifeOnHit.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Life Regenerated per second
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LifeRegen.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Mana Gained on Kill
        {
            ; Not a typo: 'G' in Gained is capital here as opposed to 'Life gained'
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ManaOnKill.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Mana Regeneration Rate
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ManaRegen.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Projectile Speed
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ProjectileSpeed.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, reduced Attribute Requirements
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ReducedAttrReqs.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to all Elemental Resistances
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\AllResist.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Fire Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FireResist.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Lightning Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LightningResist.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Cold Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ColdResist.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Chaos Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ChaosResist.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        If RegExMatch(A_LoopField, ".*to (Cold|Fire|Lightning) and (Cold|Fire|Lightning) Resistances")
        {
            ; Catches two-stone rings and the like which have "+#% to Cold and Lightning Resistances"
            IfInString, A_LoopField, Fire
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\FireResist.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
            IfInString, A_LoopField, Lightning
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\LightningResist.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
            IfInString, A_LoopField, Cold
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\ColdResist.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
            IfInString, A_LoopField, Chaos
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\ChaosResist.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
        }
        IfInString, A_LoopField, increased Stun Duration on enemies
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\StunDuration.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, reduced Enemy Stun Threshold
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\StunThreshold.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        
        ; Prefixes
        
        IfInString, A_LoopField, to Armour
        {
            NumPrefixes += 1
            If (ItemBaseType = "Item")
            {
                ; Global
                ValueRange := LookupAffixData("data\ToArmour_Items.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Else
            {
                ; Local
                ValueRange := LookupAffixData("data\ToArmour_WeaponsAndArmour.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Continue
        }
        IfInString, A_LoopField, increased Armour and Evasion
        {
            AffixType := "Prefix"
            If (HasStunRecovery) 
            {
                AffixType := "Comp. Prefix"
            }
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\ArmourAndEvasion.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Armour and Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\ArmourAndEnergyShield.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Evasion and Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\EvasionAndEnergyShield.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Armour
        {
            NumPrefixes += 1
            If (ItemBaseType == "Item")
            {
                ; Global
                ValueRange := LookupAffixData("data\IncrArmour_Items.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Else
            {
                ; Local
                ValueRange := LookupAffixData("data\IncrArmour_WeaponsAndArmour.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Continue
        }
        IfInString, A_LoopField, to Evasion Rating
        {
            NumPrefixes += 1
            If (ItemBaseType == "Item")
            {
                ValueRange := LookupAffixData("data\ToEvasion_Items.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Else
            {
                ValueRange := LookupAffixData("data\ToEvasion_Armour.txt", ItemLevel, CurrValue)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Continue
        }
        IfInString, A_LoopField, increased Evasion Rating
        {
            NumPrefixes += 1
            If (ItemBaseType == "Item")
            {
                ValueRange := LookupAffixData("data\IncrEvasion_Items.txt", ItemLevel, CurrValue)
            }
            Else
            {
                ValueRange := LookupAffixData("data\IncrEvasion_Armour.txt", ItemLevel, CurrValue)
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\ToEnergyShield_ArmourAndShields.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to maximum Energy Shield
        {
            If (ItemSubType == "Ring")
            {
                ValueRange := LookupAffixData("data\ToMaxEnergyShield_Rings.txt", ItemLevel, CurrValue)
            }
            Else
            {
                ValueRange := LookupAffixData("data\ToMaxEnergyShield_AmuletsAndBelts.txt", ItemLevel, CurrValue)
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, increased Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\IncrEnergyShield_ArmourAndShields.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased maximum Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\IncrMaxEnergyShield_Amulets.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Physical Damage
        {
            AffixType := "Prefix"
            NumPrefixes += 1
            If (HasToAccuracyRating)
            {
                If (ItemSubType == "Mace" and ItemGripType == "2H")
                {
                    ValueRange := LookupAffixBracket("data\IncrPhysDamage_AccuracyRating_2HMaces.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    ValueRange := LookupAffixBracket("data\IncrPhysDamage_AccuracyRating.txt", ItemLevel, CurrValue)
                }
                If (ValueRange == "n/a") 
                {
                    ; no bracket found? treat as non-composite prefix
                    ValueRange := LookupAffixData("data\IncrPhysDamage.txt", ItemLevel, CurrValue)
                    HasIncrPhysDmg := False
                    ARPartial =
                }
                Else
                {
                    BracketLevel := 0
                    If (ItemSubType == "Mace" and ItemGripType == "2H")
                    {
                        ValueRange := LookupAffixData("data\IncrPhysDamage_AccuracyRating_2HMaces.txt", ItemLevel, CurrValue, BracketLevel)
                        ValueRangeAR := LookupAffixBracket("data\IncrPhysDamage_AccuracyRating_AROnly_2HMaces.txt", BracketLevel)
                        If (Not ValueRangeAR == "n/a")
                        {
                            ARPartial := ValueRangeAR
                        }
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\IncrPhysDamage_AccuracyRating.txt", ItemLevel, CurrValue, BracketLevel)
                        ValueRangeAR := LookupAffixBracket("data\IncrPhysDamage_AccuracyRating_AROnly.txt", BracketLevel)
                        If (Not ValueRangeAR == "n/a")
                        {
                            ARPartial := ValueRangeAR
                        }
                    }
                }
            }
            Else
            {
                ValueRange := LookupAffixData("data\IncrPhysDamage.txt", ItemLevel, CurrValue)
            }
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            Continue
        }        
        If RegExMatch(A_LoopField, "Adds \d+?\-\d+? Physical Damage")
        {
            If (ItemBaseType == "Weapon")
            {
                If (ItemSubType == "Bow")
                {
                    ValueRange := LookupAffixData("data\AddedPhysDamage_2H.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    If (ItemGripType == "1H") ; one handed weapons
                    {
                        ValueRange := LookupAffixData("data\AddedPhysDamage_1H.txt", ItemLevel, CurrValue)
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\AddedPhysDamage_2H.txt", ItemLevel, CurrValue)
                    }
                }
            }
            Else
            {
                If (ItemSubType == "Amulet")
                {
                    ValueRange := LookupAffixData("data\AddedPhysDamage_Amulets.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    If (ItemSubType == "Quiver")
                    {
                        ValueRange := LookupAffixData("data\AddedPhysDamage_Quivers.txt", ItemLevel, CurrValue)
                    }
                    Else
                    {
                        If (ItemSubType == "Ring")
                        {
                            ValueRange := LookupAffixData("data\AddedPhysDamage_Rings.txt", ItemLevel, CurrValue)
                        }
                        Else
                        {
                            ; there is no Else for rare items, but some uniques have added phys damage
                            ; just lookup in 1H for now
                            ValueRange := LookupAffixData("data\AddedPhysDamage_Amulets.txt", ItemLevel, CurrValue)
                        }
                    }
                }
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        If RegExMatch(A_LoopField, "Adds \d+?\-\d+? Cold Damage")
        {
            If (ItemSubType == "Amulet" or ItemSubType == "Ring")
            {
                ValueRange := LookupAffixData("data\AddedColdDamage_RingsAndAmulets.txt", ItemLevel, CurrValue)
            }
            Else
            {
                If (ItemSubType == "Gloves")
                {
                    ValueRange := LookupAffixData("data\AddedColdDamage_Gloves.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    If (ItemSubType == "Quiver")
                    {
                        ValueRange := LookupAffixData("data\AddedColdDamage_Quivers.txt", ItemLevel, CurrValue)
                    }
                    Else
                    {
                        If (ItemGripType == "1H")
                        {
                            ValueRange := LookupAffixData("data\AddedColdDamage_1H.txt", ItemLevel, CurrValue)
                        }
                        Else
                        {
                            ValueRange := LookupAffixData("data\AddedColdDamage_2H.txt", ItemLevel, CurrValue)
                        }
                    }
                }
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        If RegExMatch(A_LoopField, "Adds \d+?\-\d+? Fire Damage")
        {
            If (ItemSubType == "Amulet" or ItemSubType == "Ring")
            {
                ValueRange := LookupAffixData("data\AddedFireDamage_RingsAndAmulets.txt", ItemLevel, CurrValue)
            }
            Else
            {
                If (ItemSubType == "Gloves")
                {
                    ValueRange := LookupAffixData("data\AddedFireDamage_Gloves.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    If (ItemSubType == "Quiver")
                    {
                        ValueRange := LookupAffixData("data\AddedFireDamage_Quivers.txt", ItemLevel, CurrValue)
                    }
                    Else
                    {
                        If (ItemGripType == "1H") ; one handed weapons
                        {
                            ValueRange := LookupAffixData("data\AddedFireDamage_1H.txt", ItemLevel, CurrValue)
                        }
                        Else
                        {
                            ValueRange := LookupAffixData("data\AddedFireDamage_2H.txt", ItemLevel, CurrValue)
                        }
                    }
                }
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        If RegExMatch(A_LoopField, "Adds \d+?\-\d+? Lightning Damage")
        {
            If (ItemSubType == "Amulet" or ItemSubType == "Ring")
            {
                ValueRange := LookupAffixData("data\AddedLightningDamage_RingsAndAmulets.txt", ItemLevel, CurrValue)
            }
            Else
            {
                If (ItemSubType == "Gloves")
                {
                    ValueRange := LookupAffixData("data\AddedLightningDamage_Gloves.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    If (ItemSubType == "Quiver")
                    {
                        ValueRange := LookupAffixData("data\AddedLightningDamage_Quivers.txt", ItemLevel, CurrValue)
                    }
                    Else
                    {
                        If (ItemGripType == "1H") ; one handed weapons
                        {
                            ValueRange := LookupAffixData("data\AddedLightningDamage_1H.txt", ItemLevel, CurrValue)
                        }
                        Else
                        {
                            ValueRange := LookupAffixData("data\AddedLightningDamage_2H.txt", ItemLevel, CurrValue)
                        }
                    }
                }
            }
            ActualRange := GetActualValue(A_LoopField)
            AffixType := "Prefix"
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Physical Damage to Melee Attackers
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\PhysDamageReturn.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Gems in this item
        {
            If (ItemBaseType == "Weapon")
            {
                If (ItemSubType == "Bow")
                {
                    ValueRange := LookupAffixData("data\GemLevel_Bow.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    If (InStr(A_LoopField, "Fire") or InStr(A_LoopField, "Cold") or InStr(A_LoopField, "Lightning"))
                    {
                        ValueRange := LookupAffixData("data\GemLevel_Elemental.txt", ItemLevel, CurrValue)
                    }
                    Else
                    {
                        If (InStr(A_LoopField, "Melee"))
                        {
                            ValueRange := LookupAffixData("data\GemLevel_Melee.txt", ItemLevel, CurrValue)
                        }
                        Else
                        {
                            ; Paragorn's
                            ValueRange := LookupAffixData("data\GemLevel.txt", ItemLevel, CurrValue)
                        }
                    }
                }
            }
            Else
            {
                ValueRange := LookupAffixData("data\GemLevel_Minion.txt", ItemLevel, CurrValue)
            }
            NumPrefixes += 1
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, maximum Life
        {
            ValueRange := LookupAffixData("data\MaxLife.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, maximum Mana
        {
            AffixType := "Prefix"
            If (HasSpellDamage and MaxManaPartial)
            {
;                msgbox, MaxManaPartial: %MaxManaPartial%
                If (NumPrefixes < 3)
                {
                    NumPrefixes += 1
                    AffixType := "Comp. Prefix+Prefix"
                    ValueRange := LookupAffixBracket("data\MaxMana_SpellDamage_StaffAnd1H.txt", ItemLevel, CurrValue)
                    If (ValueRange == "n/a")
                    {
                        ; avg of the already existing max mana
                        ActualValue := CurrValue-RangeAverage(MaxManaPartial)
                        ValueRange1 := LookupAffixBracket("data\MaxMana.txt", ItemLevel, ActualValue)
                        ValueRange2 := MaxManaPartial
                        ValueRange := AddRange(ValueRange1, ValueRange2)
                        Global ValueRangeFieldWidth
                        ValueRange :=  StrPad(ValueRange . EstInd, ValueRangeFieldWidth + StrLen(EstInd), "left")
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\MaxMana_SpellDamage_StaffAnd1H.txt", ItemLevel, CurrValue)
                    }
                }
                Else
                {
                    AffixType := "Comp. Prefix"
                    ValueRange := LookupAffixData("data\MaxMana.txt", ItemLevel, CurrValue)
                }
            }
            Else
            {
                NumPrefixes += 1
                ValueRange := LookupAffixData("data\MaxMana.txt", ItemLevel, CurrValue)
            }
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Physical Attack Damage Leeched as
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\LifeLeech.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Movement Speed
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\MovementSpeed.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Spell Damage
        {
            AffixType := "Prefix"
            If (HasMaxMana)
            {
                If (ItemSubType == "Staff")
                {
                    BracketLevel := 0
                    ValueRange := LookupAffixData("data\SpellDamage_MaxMana_Staves.txt", ItemLevel, CurrValue, BracketLevel)
                    MaxManaRange := LookupAffixBracket("data\MaxMana_SpellDamage_StaffAnd1H.txt", BracketLevel)
                }
                Else
                {
                    BracketLevel := 0
                    ValueRange := LookupAffixData("data\SpellDamage_MaxMana_1H.txt", ItemLevel, CurrValue, BracketLevel)
                    MaxManaRange := LookupAffixBracket("data\MaxMana_SpellDamage_StaffAnd1H.txt", BracketLevel)
                }
                If (Not MaxManaRange == "n/a")
                {
                    MaxManaPartial := MaxManaRange
                }
                Else
                {
                    HasSpellDamage := False
                }
                AffixType := "Comp. Prefix"
            }
            Else
            {
                If (ItemSubType == "Amulet")
                {
                    ValueRange := LookupAffixData("data\SpellDamage_Amulets.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    If (ItemSubType == "Staff")
                    {
                        ValueRange := LookupAffixData("data\SpellDamage_Staves.txt", ItemLevel, CurrValue)
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\SpellDamage_1H.txt", ItemLevel, CurrValue)
                    }
                }
            }
            NumPrefixes += 1
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Elemental Damage with Weapons
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\IncrWeaponElementalDamage.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }

        ; Flask effects (on belts)
        IfInString, A_LoopField, increased Flask Mana Recovery rate
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\FlaskManaRecoveryRate.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Flask Life Recovery rate
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\FlaskLifeRecoveryRate.txt", ItemLevel, CurrValue)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }

        ; Flask prefixes
        IfInString, A_LoopField, Recovery Speed
        {
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Amount Recovered
        {
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Charges
        {
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Instant
        {
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Charge when
        {
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Recovery when
        {
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Mana Recovered
        {
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Life Recovered
        {
            NumPrefixes += 1
            Continue
        }

        ; Prefixes OR Suffixes

        IfInString, A_LoopField, increased Block and Stun Recovery
        {
            ; Unfortunately Block and Stun Recovery is completely ambiguous. There is no reliable 
            ; way to tell if it is a prefix or suffix.
            ;
            ; I have seen items that had block and stun recovery together with augmented ES or Armour 
            ; so BS Recovery should have been a prefix but actually was a suffix and vice versa.
            ; Best I can do right now is to monkeypatch. That is, check tables in order of most probable
            ; occurence, add things together in a way that makes the most sense and determine if the resulting
            ; range is out-of-bounds for the actual value as displayed in the ingame tooltip. If so, switch to 
            ; the other affix type and re-check the range. If it still doesn't fit, try a compound prefix-suffix
            ; approach.

;            ; Get actual value on ingame tooltip as a number
;            ActualValue := RegExReplace(A_LoopField, "(\d+).*", "$1") ; matches "16% increased Block and Stun Recovery", returns "16"

            AffixType := "Suffix"
            ArmourHi := 0
            ArmourLo := 0
            If (InStr(AugmentedStats, "'Armour'"))
            {
                ValueRangeArmour := LookupAffixData("data\StunRecovery_Armour.txt", ItemLevel, CurrValue)
                ParseRange(ValueRangeArmour, ArmourHi, ArmourLo)
            }
            ESHi := 0
            ESLo := 0
            If (InStr(AugmentedStats, "'Energy Shield'"))
            {
                ValueRangeES := LookupAffixData("data\StunRecovery_EnergyShield.txt", ItemLevel, CurrValue)
                ParseRange(ValueRangeES, ESHi, ESLo)
            }
            ERHi := 0
            ERLo := 0
            If (InStr(AugmentedStats, "'Evasion Rating'"))
            {
                ValueRangeER := LookupAffixData("data\StunRecovery_Evasion.txt", ItemLevel, CurrValue)
                ParseRange(ValueRangeER, ERHi, ERLo)
            }
            HybridHi := 0
            HybridLo := 0
            If (HasHybridDefences)
            {
                ValueRangeHybrid := LookupAffixData("data\StunRecovery_Hybrid.txt", ItemLevel, CurrValue)
                ParseRange(ValueRangeHybrid, HybridHi, HybridLo)
                AppendAffixInfo(A_LoopField, "Comp. Prefix", ValueRangeHybrid, AffixInfo)
                Continue
            }

            ; Probably a prefix (but could be a suffix)
            ValueRange := LookupAffixData("data\StunRecovery_Prefix.txt", ItemLevel, CurrValue)
            PrefixHi := 0
            PrefixLo := 0
            ParseRange(ValueRange, PrefixHi, PrefixLo)
            If ((CurrValue >= PrefixLo) and (CurrValue <= PrefixHi)) 
            {
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
                NumPrefixes += 1
                Continue ; Between bounds: all good, don't bother with the rest...
            }

            ValueRange := LookupAffixData("data\StunRecovery_Suffix.txt", ItemLevel, CurrValue)
            SuffixHi := 0
            SuffixLo := 0
            ParseRange(ValueRange, SuffixHi, SuffixLo)
            If ((CurrValue >= SuffixLo) and (CurrValue <= SuffixHi)) ; between bounds: all good
            {
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                NumSuffixes += 1
                Continue
            }
            Continue
        }
        
        ; AR is one tough beast... currently there are the following affixes affecting AR:
        ; 1) "Accuracy Rating" (Suffix)
        ; 2) "Local Accuracy Rating" (Suffix)
        ; 3) "Light Radius / + Accuracy Rating" (Suffix) - only the first 2 entries, bc last entry combines LR with #% increased Accuracy Rating instead!
        ; 4) "Local Physical Dmg +% / Local Accuracy Rating" (Prefix)

        ; the difficulty lies in those cases that combine multiple of these affixes into one final display value
        ; currently I try and tackle this by using a trickle-through account balance approach. That is, go from
        ; most special case to most nominal, while subtracting the value that each case most likely contributes
        ; until you have a value left that can be found in the most nominal case (which is usually to AR as global suffix)
        ;
        ; Important to note here: 
        ;   ARPartial will be set during the "increased Physical Damage" case above
        
        IfInString, A_LoopField, to Accuracy Rating
        {
            ; trickle-through order:
            ; 1) increased AR, Light Radius, all except Belts, Comp. Suffix
            ; 2) to AR, Light Radius, all except Belts, Comp. Suffix
            ; 3) increased Phys Damage, to AR, Weapons, Prefix
            ; 4) to AR, all except Belts, Suffix

            ValueRangeAR := "0-0"
            AffixType := ""
            If (HasIncrLightRadius and Not HasIncrAccuracyRating) 
            {
                ; "of Shining" and "of Light"
                ValueRange := LookupAffixData("data\AccuracyRating_LightRadius_A.txt", ItemLevel, CurrValue)
                ARLRRange := LookupAffixBracket("data\AccuracyRating_LightRadius_A.txt", ItemLevel, CurrValue)
                ARLRHi := 0
                ARLRLo := 0
                ParseRange(ARLRRange, ARLRHi, ARLRLo)
                If (ARPartial)
                {
                    ; append this affix' contribution to our partial AR range
                    ARPartial := AddRange(ARPartial, ARLRRange)
                }
                NumSuffixes += 1
                AffixType := AffixType . "Comp. Suffix"
                ; test if candidate range already covers current  AR value
                CurrValueCovered := False
                If (CurrValue >= ARLRLo and CurrValue <= ARLRHi) 
                {
                    CurrValueCovered := True
                }
                If (NumPrefixes >= 3 or NumSuffixes >= 3 or CurrValueCovered)
                {
                    Goto, FinalizeAR
                }
            }
            If (ItemBaseType == "Weapon" and HasIncrPhysDmg)
            {
                ; this is one of the trickiest cases currently: if this If-construct is reached that means the item has 
                ; multiple composites - "To Accuracy Rating / Increased Light Radius" and "Increased Physical Damage 
                ; / To Accuracy Rating". On top of that it might also contain part "To Accuracy Rating" suffix, all of
                ; which are concatenated into one single "to Accuracy Rating" entry. Currently it handled most cases 
                ; if not all, but there is still the chance that the guesstimation loop in particular might fail.
                If (ARPartial)
                {
                    ActualValue := CurrValue - (RangeAverage(ARPartial))
                }
                Else
                {
                    ActualValue := CurrValue
                }
                If (ItemSubType == "Mace" and ItemGripType == "2H")
                {
                    ValueRangeAR := LookupAffixBracket("data\IncrPhysDamage_AccuracyRating_AROnly_2HMaces.txt", ItemLevel, CurrValue)
                }
                Else
                {
                    ValueRangeAR := LookupAffixBracket("data\IncrPhysDamage_AccuracyRating_AROnly.txt", ItemLevel, CurrValue)
                }
                If (ValueRangeAR == "n/a")
                {
                    If (StrLen(AffixType) > 0)
                    {
                        AffixType := AffixType . "+" . "Comp. Prefix+Suffix"
                    }
                    Else
                    {
                        AffixType := "Comp. Prefix+Suffix"
                    }

                    NumSuffixes += 1
                    NumPrefixes += 1
                    ; try to reverse engineer composition of both ranges
                    PrefixDivisor := 1
                    SuffixDivisor := 1
                    TryIndex := 0
                    GuessFound := False
                    Loop
                    {
                        TryIndex += 1
                        ValueRangeSuffix := LookupAffixBracket("data\AccuracyRating_Global.txt", ItemLevel, Floor(ActualValue/SuffixDivisor))
                        ValueRangePrefix := LookupAffixBracket("data\IncrPhysDamage_AccuracyRating_AROnly.txt", ItemLevel, Floor(ActualValue/PrefixDivisor))
                        If (ValueRangeSuffix == "n/a")
                        {
                            SuffixDivisor += 0.5
                        }
                        If (ValueRangePrefix == "n/a")
                        {
                            PrefixDivisor += 0.5
                        }
                        If ((Not ValueRangeSuffix == "n/a") and (Not ValueRangePrefix == "n/a"))
                        {
                            GuessFound := True
                            Break
                        }
                        If (TryIndex > 100)
                        {
                            ; guard against infinite loops
                            msgbox, TODO: handle case TryIndex > 100
                            Break
                        }
                    }
                    If (GuessFound)
                    {
                        ValueRange := AddRange(ValueRangePrefix, ValueRangeSuffix)
                        Global ValueRangeFieldWidth
                        ValueRange :=  StrPad(ValueRange . EstInd, ValueRangeFieldWidth + StrLen(EstInd), "left")
                    }
                }
                Else
                {
                    AffixType := "Comp. Prefix"
                    ValueRange := LookupAffixData("data\IncrPhysDamage_AccuracyRating_AROnly.txt", ItemLevel, CurrValue)
                }
                ; NumPrefixes should be incremented already by "increased Physical Damage" case
                Goto, FinalizeAR
            }
            AffixType := "Suffix"
            ValueRange := LookupAffixData("data\AccuracyRating_Global.txt", ItemLevel, CurrValue)
            NumSuffixes += 1
            Goto, FinalizeAR

        FinalizeAR:
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            Continue
        }

        IfInString, A_LoopField, increased Rarity
        {
            ActualValue := CurrValue
            ValueRangeSuffix := LookupAffixBracket("data\IIR_Suffix.txt", ItemLevel, ActualValue)
            If (ValueRangeSuffix == "n/a")
            {
                ValueRangePrefix := LookupAffixBracket("data\IIR_Prefix.txt", ItemLevel, ActualValue)
                If (ValueRangePrefix == "n/a")
                {
                    NumPrefixes += 1
                    NumSuffixes += 1
                    ; try to reverse engineer composition of both ranges
                    PrefixDivisor := 1
                    SuffixDivisor := 1
                    Loop
                    {
                        ValueRangeSuffix := LookupAffixBracket("data\IIR_Suffix.txt", ItemLevel, Floor(ActualValue/SuffixDivisor))
                        ValueRangePrefix := LookupAffixBracket("data\IIR_Prefix.txt", ItemLevel, Floor(ActualValue/PrefixDivisor))
                        If (ValueRangeSuffix == "n/a")
                        {
                            SuffixDivisor += 0.25
                        }
                        If (ValueRangePrefix == "n/a")
                        {
                            PrefixDivisor += 0.25
                        }
                        If ((Not ValueRangeSuffix == "n/a") and (Not ValueRangePrefix == "n/a"))
                        {
                            Break
                        }
                    }
                    ValueRange := AddRange(ValueRangePrefix, ValueRangeSuffix)
                    Global ValueRangeFieldWidth
                    ValueRange :=  StrPad(ValueRange . EstInd, ValueRangeFieldWidth + StrLen(EstInd), "left")
                    AppendAffixInfo(A_LoopField, "Prefix+Suffix", ValueRange, AffixInfo)
                }
                Else
                {
                    NumPrefixes += 1
                    ValueRange := LookupAffixData("data\IIR_Prefix.txt", ItemLevel, ActualValue)
                    AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
                }
            }
            Else
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\IIR_Suffix.txt", ItemLevel, ActualValue)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            }
            Continue
        }

        ; counting "extra" (e.g. unreckognized) affixes is just a 
        ; placeholder until unique items get their special treatment
        NumExtras := NumExtras + 1
    }
}

; Parse clipboard content for item level and dps
ParseClipBoardChanges() 
{
    Global IsWeapon
    Global IsUnidentified
    NameIsDone := False
    ItemName := 
    ItemLevel := -1
    IsWeapon := False
    IsUnidentified := False
    PhysLo := 0
    PhysHi := 0
    Quality := 0
    AttackSpeed := 0
    PhysMult := 0
    ChaoLo := 0
    ChaoHi := 0
    ColdLo := 0
    ColdHi := 0
    FireLo := 0
    FireHi := 0
    LighLo := 0
    LighHi := 0
 
    Global ItemData  ; d
    ItemData := GetClipboardContents() 

    Global ItemLevel ; d
    ItemLevel := ParseItemLevel(ItemData)

    Global ItemDataParts0 ; d
    ; AHK only allows splitting on single chars, so first 
    ; replace the split string (\r\n--------\r\n) with AHK's escape char (`)
    ; then do the actual string splitting...
    StringReplace, TempResult, ItemData, `r`n--------`r`n, ``, All
    StringSplit, ItemDataParts, TempResult, ``,

    Global ItemDataNamePlate ; d
    ItemDataNamePlate := ItemDataParts%ItemDataParts%1
    Global ItemDataStats ; d
    ItemDataStats := ItemDataParts%ItemDataParts%2
    Global ItemDataRequirements
    ItemDataRequirements := ItemDataParts%ItemDataParts%3

    Global RequiredAttributes
    Global RequiredLevel
    Global RequiredAttributeValues
    ParseRequirements(ItemDataRequirements, RequiredLevel, RequiredAttributes, RequiredAttributeValues)
;    msgbox, RequiredLevel: %RequiredLevel%`, RequiredAttributes: %RequiredAttributes%`, RequiredAttributeValues: %RequiredAttributeValues%

    Global ItemQuality ; d
    ItemQuality := ParseQuality(ItemDataStats)

    ; these 3 actually need to be global! (not only for debugging)
    Global ItemBaseType
    Global ItemSubType
    Global ItemGripType
    ParseItemType(ItemDataStats, ItemDataNamePlate, ItemBaseType, ItemSubType, ItemGripType)

    ; assign length of the "array" so we can either grab the 
    ; last item (if non unique) or the item before last
    Global ItemDataPartsIndexLast ; for debugging
    ItemDataPartsIndexLast := ItemDataParts0

    Global ItemDataPartsLast ; d
    ItemDataPartsLast := ItemDataParts%ItemDataParts%%ItemDataParts0%

    IfInString, ItemDataPartsLast, Unidentified
    {
        IsUnidentified := True
    }

    ; this function should return the second part of the "Rarity: ..." line
    ; in the case of "Rarity: Unique" it should return "Unique"
    Global ItemDataRarity ; for debugging
    ItemDataRarity := ParseRarity(ItemDataNamePlate)

    Global RarityLevel
    RarityLevel := CheckRarityLevel(ItemDataRarity)

    Global IsFlask
    IsFlask := False
    ; check if the user requests a tooltip for a flask
    IfInString, ItemDataPartsLast, Right click to drink
    {
        IsFlask := True
    }

    Global IsUnique
    IsUnique := False
    IfInString, ItemDataRarity, Unique
    {
        IsUnique := True
    }

    If (IsFlask or IsUnique)
    {
        ; uniques as well as flasks have descriptive text as last item,
        ; so decrement item index to get to the item before last one
        ItemDataPartsIndexAffixes := ItemDataPartsIndexLast - 1
    }
    Else
    {
        ItemDataPartsIndexAffixes := ItemDataPartsIndexLast
    }

    ; hopefully this should now hold the part of the text that
    ; deals with affixes
    Global ItemDataAffixes ; d
    ItemDataAffixes := ItemDataParts%ItemDataParts%%ItemDataPartsIndexAffixes%

    ; need to check and see what is actually being augmented for the item stats
    ; this is needed to distinguish between prefix and suffix in cases like 
    ; armour and stun recover (prefix) or just stun recovery (suffix). They would 
    ; both show as "+% increased block and stun recovery" on the item card but in 
    ; the first case the armour stat would be augmented
    Global ItemDataStats ; d
    ItemDataStats := ItemDataParts%ItemDataParts%2

    Global AugmentedStats ; d
    AugmentedStats =
    If (RarityLevel > 1)
    {
        ParseAugmentations(ItemDataStats, AugmentedStats)
    }

    If (ItemDataPartsIndexAffixes = 0)
    {
        ; ItemDataParts doesn't have the parts/text we need. Bail. 
        ; This might be because the clipboard is completely empty.
        return 
    }
    Else
    {
        ItemDataPartsIndexImplicitMods := ItemDataPartsIndexAffixes - 1
    }

    Global ItemDataImplicitMods ; d
    ItemDataImplicitMods := ItemDataParts%ItemDataParts%%ItemDataPartsIndexImplicitMods%

    Global AffixInfo
    AffixInfo =

    Global NumPrefixes ; d
    Global NumSuffixes ; d
    Global TotalAffixes ; d
    TotalAffixes := 0
    NumPrefixes := 0
    NumSuffixes := 0
    NumExtras := 0

    If (RarityLevel > 1)
    {
        ParseAffixes(ItemDataAffixes, ItemLevel, ItemQuality, ItemDataImplicitMods, AugmentedStats, AffixInfo, NumPrefixes, NumSuffixes, NumExtras)
        TotalAffixes := NumPrefixes + NumSuffixes + NumExtras
    }

    Loop, Parse, Clipboard, `n, `r
    {
        ; Clipboard must have "Rarity:" in the first line
        If A_Index = 1
        {
            IfNotInString, A_LoopField, Rarity:
            {
                Exit
            } 
            Else 
            {
                Continue
            }
        }

        ; Get name
        If Not NameIsDone 
        {
            If A_LoopField = --------
            {
                NameIsDone := True
            } 
            Else 
            {
                ItemName := ItemName . A_LoopField . "`n" ; Add a line of name
                CheckBaseLevel(ItemName) ; Checking for base item level.
            }
            Continue
        }
        
        ; Get item level
        IfInString, A_LoopField, Itemlevel:
        {
            StringSplit, ItemLevelArray, A_LoopField, %A_Space%
            ItemLevel := ItemLevelArray2
            Continue
        }
        
        ; Get quality
        IfInString, A_LoopField, Quality:
        {
            StringSplit, Arr, A_LoopField, %A_Space%, +`%
            Quality := Arr2
            Continue
        }
        
        ; Get total physical damage
        IfInString, A_LoopField, Physical Damage:
        {
            IsWeapon := True
            StringSplit, Arr, A_LoopField, %A_Space%
            StringSplit, Arr, Arr3, -
            PhysLo := Arr1
            PhysHi := Arr2
            Continue
        }
        
        ; Fix for Elemental damage only weapons. Like the Oro's Sacrifice
        IfInString, A_LoopField, Elemental Damage:
        {
            IsWeapon := True
            Continue
        }
        
        ; These only make sense for weapons
        If IsWeapon {
            ; Get attack speed
            IfInString, A_LoopField, Attacks per Second:
            {
                StringSplit, Arr, A_LoopField, %A_Space%
                AttackSpeed := Arr4
                Continue
            }
            
            ; Get percentage physical damage increase
            IfInString, A_LoopField, increased Physical Damage
            {
                StringSplit, Arr, A_LoopField, %A_Space%, `%
                PhysMult := Arr1
                Continue
            }
            
            ;Lines to skip fix for converted type damage. Like the Voltaxic Rift
            IfInString, A_LoopField, Converted to
                Goto, SkipDamageParse
            IfInString, A_LoopField, can Shock
                Goto, SkipDamageParse
            
            ; Parse elemental damage
            ParseDamage(A_LoopField, "Chaos", ChaoLo, ChaoHi)
            ParseDamage(A_LoopField, "Cold", ColdLo, ColdHi)
            ParseDamage(A_LoopField, "Fire", FireLo, FireHi)
            ParseDamage(A_LoopField, "Lightning", LighLo, LighHi)
            
            SkipDamageParse:
                DoNothing := True
        }
    }
    If (ItemLevel = -1) ; Something without an itemlevel
    { 
        Exit
    }

    ; Get position of mouse cursor
    Global X
    Global Y
    MouseGetPos, X, Y
 
    ; All items should show name and item level
    ; Pad to 3 places
    ItemLevel := "   " . ItemLevel
    StringRight, ItemLevel, ItemLevel, 3

    ;global TT
    TT = %ItemName%Item lvl:  %ItemLevel%
 
    ; DPS calculations
    If IsWeapon 
    {
        SetFormat, FloatFast, 5.1

        ;Global PhysDps
        ;Global EleDps
        ;Global TotalDps
        PhysDps := ((PhysLo + PhysHi) / 2) * AttackSpeed
        EleDps := ((ChaoLo + ChaoHi + ColdLo + ColdHi + FireLo + FireHi + LighLo + LighHi) / 2) * AttackSpeed
        TotalDps := PhysDps + EleDps
        
        TT = %TT%`nPhys DPS:  %PhysDps%`nElem DPS:  %EleDps%`nTotal DPS: %TotalDps%
        
        ; Only show Q20 values if item is not Q20
        If (Quality < 20) {
            TotalPhysMult := (PhysMult + Quality + 100) / 100
            BasePhysDps := PhysDps / TotalPhysMult
            Q20Dps := BasePhysDps * ((PhysMult + 120) / 100) + EleDps
            
            TT = %TT%`nQ20 DPS:   %Q20Dps%
        }
    }

    ; Append affix info if rarity is greater than normal (white)

    ; Affix total statistic
    Global ShowAffixTotals
    If (ShowAffixTotals = 1)
    {
        If (RarityLevel > 1 and RarityLevel < 4)
        {

            If (NumPrefixes = 1) 
            {
                WordPrefixes = Prefix
            }
            Else
            {
                WordPrefixes = Prefixes
            }
            If (NumSuffixes = 1) 
            {
                WordSuffixes = Suffix
            }
            Else
            {
                WordSuffixes = Suffixes
            }

            PrefixLine = 
            If (NumPrefixes > 0) 
            {
                PrefixLine = `n   %NumPrefixes% %WordPrefixes%
            }

            SuffixLine =
            If (NumSuffixes > 0)
            {
                SuffixLine = `n   %NumSuffixes% %WordSuffixes%
            }

            AffixStats =
            If (TotalAffixes > 0 and Not IsUnidentified)
            {
                AffixStats = Affixes (%TotalAffixes%):%PrefixLine%%SuffixLine%
                If (NumExtras > 0) 
                {
                    AffixStats = %AffixStats%`n   %NumExtras% Extra
                }
                TT = %TT%`n--------`n%AffixStats%
            }
        }
        Else
        {
            If (RarityLevel = 4)
            {
                TT = %TT%`n--------`nUnique item currently not supported
            }
        }
    }

    ; Detailed affix range infos
    Global ShowAffixDetails
    If (ShowAffixDetails = 1)
    {
        If (Not IsFlask and Not IsUnidentified)
        {
            If (RarityLevel > 1 and RarityLevel < 4)
            {
                TT = %TT%`n--------%AffixInfo%
            }
            If (RarityLevel == 4)
            {
                If (Not ShowAffixTotals)
                {
                    TT = %TT%`n--------`nUnique item currently not supported
                }
            }
       }

    }
    ; TODO: enable preference setting for replacing the clipboard with constructed tooltip text
    ; Replaces Clipboard with tooltip data
    ;SetClipboardContents(TT)

    ; Show tooltip, with fixed width font
    ToolTip, %TT%, X + 35, Y + 35
    Global FixedFont
    SetFont(FixedFont)

    ; Set up count variable and start timer for tooltip timeout
    Global ToolTipTimeout := 0
    SetTimer, ToolTipTimer, 100
}
 
; Tick every 100 ms
; Remove tooltip if mouse is moved or 5 seconds pass
ToolTipTimer:
    ToolTipTimeout += 1
    MouseGetPos, CurrX, CurrY
    MouseMoved := (CurrX - X)**2 + (CurrY - Y)**2 > MouseMoveThreshold**2
    If (MouseMoved or ((UseTooltipTimeout = 1) and (ToolTipTimeout >= ToolTipTimeoutTicks)))
    {
        SetTimer, ToolTipTimer, Off
        ToolTip
    }
    return

OnClipBoardChange:
    ParseClipBoardChanges()
