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
; edit by non-coders. Each line in those text files has the form "max-level|value-range".
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
;     one final entry on the ingame tooltip there is now reliable way to work backwards from the 
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
; Todo:
;   - handle ranges for implicit mods
;   - handle unique items specially
;
; Notes:
;   - Global values marked with an inline comment "d" are globals for debugging so they can be searched 
;     and replaced easily. Marking variables as global means they will show up in AHK's Variables and 
;     contents view of the script.
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
#IfWinActive, Path of Exile

#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
#Persistent ; Stay open in background
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
StringCaseSense, On ; Match strings with case.

; Windows system tray icon
; possible values: poe.ico, poe-bw.ico, poe-web.ico, info.ico
Menu, tray, Icon, data\poe-bw.ico
 
; OPTIONS

; Base item level display.

DisplayBaseLevel = 1 ; Enabled by default change to 0 to disable
ShowAffixTotals  = 1 ; Show total affix statistics
ShowAffixDetails = 1 ; Show detailed info about affixes

MirrorAffixLines = 1 ; Show a copy of the affix line in question when showing affix details. 
; For example, would display "Prefix, 5-250" instead of "+246 to Accuracy Rating, Prefix, 5-250". 
; Since the affixes are processed in order one can attribute which is which to the ordering of 
; the lines in the tooltip to the item data in game.

; Pixels mouse must move to auto-dismiss tooltip
MouseMoveThreshold := 40

;How many ticks to wait before removing tooltip. 1 tick = 100ms. Example, 50 ticks = 5secends, 75 Ticks = 7.5Secends
ToolTipTimeoutTicks := 150

; Font size for the tooltip, leave empty for default
FontSize := 12

; Menu tooltip
Menu, tray, Tip, Path of Exile Item Infos
 
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
    ; grip type only matters for weapons at this point. For all others it will be "None"
    GripType = None

    ; check stats section first as weapons usually have their sub type as first line
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
            ; yeah, I know one handed bow doesn't make much sense but that's how 
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

    ; check name plate section 
    Loop, Parse, ItemDataNamePlate, `n, `r
    {
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

SplitString(StrInput, StrDelimiter) ; UNUSED currently
{
    TempDelim := "``"
    ;Global TempResult
    StringReplace, TempResult, StrInput, %StrDelimiter%, %TempDelim%, All
    ;Global Parts0
    StringSplit, Parts, TempResult, %TempDelim%
    return Parts
}

LookupAffixData(Filename, BaseLevel)
{
    Global MaxLevel
    Global LastRangeValues
    Global FirstRangeValues
    LastRangeValues =
    FirstRangeValues = 
    MaxLevel := 0
    AffixDataIndex := 0
    Loop, Read, %A_WorkingDir%\%Filename%
    {  
        AffixDataIndex += 1
        StringSplit, AffixDataParts, A_LoopReadLine, |,
        MaxLevel := AffixDataParts1
        RangeValues := AffixDataParts2
        If (MaxLevel > BaseLevel)
        {
            Break
        }
        If (AffixDataIndex = 1)
        {
            FirstRangeValues := RangeValues
            LastRangeValues := RangeValues
        }
        LastRangeValues := RangeValues
    }
    Global LoVal
    IfInString, FirstRangeValues, -
    {
        StringSplit, FirstRangeParts, FirstRangeValues, -
        LoVal := FirstRangeParts%FirstRangeParts%1
    }
    Else
    {
        LoVal := FirstRangeValues
    }
    Global HiVal
    IfInString, LastRangeValues, -
    {
        StringSplit, LastRangeParts, LastRangeValues, -
        HiVal := LastRangeParts%LastRangeParts%2
    }
    Else
    {
        HiVal := LastRangeValues
    }
    If (HiVal = LoVal)
    {
        FinalRange = %LoVal%
    }
    Else
    {
        FinalRange = %LoVal%-%HiVal%
    }
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


ParseRange(RangeChunk, ByRef Hi, ByRef Lo)
{
    StringSplit, RangeParts, RangeChunk, -
    Lo := RegExReplace(RangeParts1, "(\d+?)", "$1")
    Hi := RegExReplace(RangeParts2, "(\d+?)", "$1")
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

AppendAffixInfo(AffixLine, AffixType, ValueRange, ByRef AffixInfo)
{
    Line =
    Delim := ", "
    Global MirrorAffixLines
    If (MirrorAffixLines = 1)
    {
        Line := AffixLine . Delim
    }
    Line := Line . AffixType . Delim . ValueRange
    AffixInfo := AffixInfo . "`n" . Line
}

AdjustRangeForQuality(ValueRange, ItemQuality)
{
    If (ItemQuality = 0)
    {
        return ValueRange
    }
    VRHi := 0
    VRLo := 0
    ParseRange(ValueRange, VRHi, VRLo)
    Divisor := ItemQuality / 100
    VRHi := Round(VRHi + (VRHi * Divisor))
    VRLo := Round(VRLo + (VRLo * Divisor))
    ValueRange = %VRLo%-%VRHi%
    return ValueRange
}

ParseAffixes(ItemDataChunk, ItemLevel, ItemQuality, ImplicitMods, AugmentedStats, ByRef AffixInfo, ByRef NumPrefixes, ByRef NumSuffixes, ByRef NumExtras)
{
    Global ItemBaseType
    Global ItemSubType
    Global ItemGripType

    ; composition flags
    HasIIQ := False
    HasIncrEvasion := False
    HasIncrEnergyShield := False
    HasHybridDefences := False
    HasIncrLightRadius := False

    ; prepass to determine composition flags
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

        ; Suffixes

        IfInString, A_LoopField, increased Attack Speed
        {
            NumSuffixes += 1
            If (ItemBaseType == "Weapon") ; ItemBaseType is global!
            {
                ValueRange := LookupAffixData("data\AttackSpeed_Weapons.txt", ItemLevel)
            }
            Else
            {
                ValueRange := LookupAffixData("data\AttackSpeed_ArmourAndItems.txt", ItemLevel)
            }
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to all Attributes 
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToAllAttributes.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Strength
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToStrength.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Intelligence
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToIntelligence.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Dexterity
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ToDexterity.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Cast Speed
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\CastSpeed.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        ; this needs to come before "Critical Strike Chance" !
        IfInString, A_LoopField, increased Critical Strike Chance for Spells
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\SpellCritChance.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Critical Strike Chance
        {
            If (ItemSubType == "Quiver" or ItemSubType == "Amulet")
            {
                ValueRange := LookupAffixData("data\CritChance_AmuletsAndQuivers.txt", ItemLevel)
            }
            Else
            {
                ValueRange := LookupAffixData("data\CritChance_Weapons.txt", ItemLevel)
            }
            NumSuffixes += 1
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Critical Strike Multiplier
        {
            If (ItemSubType == "Quiver" or ItemSubType == "Amulet")
            {
                ValueRange := LookupAffixData("data\CritMultiplier_AmuletsAndQuivers.txt", ItemLevel)
            }
            Else
            {
                ValueRange := LookupAffixData("data\CritMultiplier_Weapons.txt", ItemLevel)
            }
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            NumSuffixes += 1
            Continue
        }
        IfInString, A_LoopField, increased Fire Damage
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\IncrFireDamage.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Cold Damage
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\IncrColdDamage.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Lightning Damage
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\IncrLightningDamage.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Light Radius
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LightRadius.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Block chance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\BlockChance.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }

        ; flask effects (on belts)
        IfInString, A_LoopField, reduced Flask Charges used
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FlaskChargesUsed.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Flask Charges gained
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FlaskChargesGained.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Flask effect duration
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FlaskDuration.txt", ItemLevel)
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
            ValueRange := LookupAffixData("data\IIQ.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Life gained on Kill
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LifeOnKill.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Life gained for each enemy hit by your Attacks
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LifeOnHit.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Life Regenerated per second
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LifeRegen.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Mana Gained on Kill
        {
            ; not a typo: G in Gained is capital here as opposed to Life gained
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ManaOnKill.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Mana Regeneration Rate
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ManaRegen.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Projectile Speed
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ProjectileSpeed.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, reduced Attribute Requirements
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ReducedAttrReqs.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to all Elemental Resistances
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\AllResist.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Fire Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\FireResist.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Lightning Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\LightningResist.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Cold Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ColdResist.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Chaos Resistance
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\ChaosResist.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        If RegExMatch(A_LoopField, ".*to (Cold|Fire|Lightning) and (Cold|Fire|Lightning) Resistances")
        {
            ; catches two-stone rings and the like which have "+#% to Cold and Lightning Resistances"
            IfInString, A_LoopField, Fire
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\FireResist.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
            IfInString, A_LoopField, Lightning
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\LightningResist.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
            IfInString, A_LoopField, Cold
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\ColdResist.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
            IfInString, A_LoopField, Chaos
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\ChaosResist.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                Continue
            }
        }
        IfInString, A_LoopField, increased Stun Duration on enemies
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\StunDuration.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, reduced Enemy Stun Threshold
        {
            NumSuffixes += 1
            ValueRange := LookupAffixData("data\StunThreshold.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            Continue
        }

        ; Prefixes

        IfInString, A_LoopField, to Armour
        {
            NumPrefixes += 1
            If (ItemBaseType = "Item")
            {
                ; global
                ValueRange := LookupAffixData("data\ToArmour_Items.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Else
            {
                ; local
                ValueRange := LookupAffixData("data\ToArmour_WeaponsAndArmour.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Continue
        }
        IfInString, A_LoopField, increased Armour and Evasion
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\ArmourAndEvasion.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Armour and Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\ArmourAndEnergyShield.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Evasion and Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\EvasionAndEnergyShield.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Armour
        {
            NumPrefixes += 1
            If (ItemBaseType == "Item")
            {
                ; global
                ValueRange := LookupAffixData("data\IncrArmour_Items.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Else
            {
                ; local
                ValueRange := LookupAffixData("data\IncrArmour_WeaponsAndArmour.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Continue
        }
        IfInString, A_LoopField, to Evasion Rating
        {
            NumPrefixes += 1
            If (ItemBaseType == "Item")
            {
                ValueRange := LookupAffixData("data\ToEvasion_Items.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Else
            {
                ValueRange := LookupAffixData("data\ToEvasion_Armour.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            }
            Continue
        }
        IfInString, A_LoopField, increased Evasion Rating
        {
            NumPrefixes += 1
            If (ItemBaseType == "Item")
            {
                ValueRange := LookupAffixData("data\IncrEvasion_Items.txt", ItemLevel)
            }
            Else
            {
                ValueRange := LookupAffixData("data\IncrEvasion_Armour.txt", ItemLevel)
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\ToEnergyShield_ArmourAndShields.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, to maximum Energy Shield
        {
            If (ItemSubType == "Ring")
            {
                ValueRange := LookupAffixData("data\ToMaxEnergyShield_Rings.txt", ItemLevel)
            }
            Else
            {
                ValueRange := LookupAffixData("data\ToMaxEnergyShield_AmuletsAndBelts.txt", ItemLevel)
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, increased Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\IncrEnergyShield_ArmourAndShields.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased maximum Energy Shield
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\IncrMaxEnergyShield_Amulets.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Physical Damage
        {
            ; if it has an implicit accuracy mod it is Damage + Accuracy, otherwise just Damage 
            NumPrefixes += 1
            DoublePrefix := False
            ActualValue := RegExReplace(A_LoopField, "(\d+).*", "$1") ; matches "99% increased Physical Damage", returns "99"
            ValueRangePDAR := LookupAffixData("data\IncrPhysDamage_AccuracyRating.txt", ItemLevel)
            ValueRangePD := LookupAffixData("data\IncrPhysDamage.txt", ItemLevel)
            IfInString, ImplicitMods, Accuracy Rating
            {
                PDARHi := 0
                PDARLo := 0
                PDHi := 0
                PDLo := 0
                ParseRange(ValueRangePDAR, PDARHi, PDARLo)
                ParseRange(ValueRangePD, PDHi, PDLo)
                If ((ActualValue < PDARLo) or (ActualValue > PDARHi))
                {
                    ; looks like a double prefix? calculate a composite value range for 
                    ; "Increased Physical Damage"
                    ; "Increased Physical Damage / Accuracy Rating"
                    FinalHi := PDARHi + PDHi
                    FinalLo := PDARLo + PDLo
                    ValueRange = %FinalLo%-%FinalHi%
                }
            }
            Else
            {
                ValueRange := ValueRangePD
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }        
        If RegExMatch(A_LoopField, "Adds \d+?\-\d+? Physical Damage")
        {
            If (ItemBaseType == "Weapon")
            {
                If (ItemGripType == "1H") ; one handed weapons
                {
                    ValueRange := LookupAffixData("data\AddedPhysDamage_1H.txt", ItemLevel)
                }
                Else
                {
                    ValueRange := LookupAffixData("data\AddedPhysDamage_2H.txt", ItemLevel)
                }
            }
            Else
            {
                If (ItemSubType == "Amulet")
                {
                    ValueRange := LookupAffixData("data\AddedPhysDamage_Amulets.txt", ItemLevel)
                }
                Else
                {
                    If (ItemSubType == "Ring")
                    {
                        ValueRange := LookupAffixData("data\AddedPhysDamage_Rings.txt", ItemLevel)
                    }
                    Else
                    {
                        ; there is no Else for rare items, but some uniques have added phys damage
                        ; just lookup in 1H for now
                        ValueRange := LookupAffixData("data\AddedPhysDamage_1H.txt", ItemLevel)
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
                ValueRange := LookupAffixData("data\AddedColdDamage_RingsAndAmulets.txt", ItemLevel)
            }
            Else
            {
                If (ItemSubType == "Gloves")
                {
                    ValueRange := LookupAffixData("data\AddedColdDamage_Gloves.txt", ItemLevel)
                }
                Else
                {
                    If (ItemGripType == "1H")
                    {
                        ValueRange := LookupAffixData("data\AddedColdDamage_1H.txt", ItemLevel)
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\AddedColdDamage_2H.txt", ItemLevel)
                    }
                }
            }
            If (ItemQuality > 0)
            {
                ValueRange := AdjustRangeForQuality(ValueRange, ItemQuality)
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        If RegExMatch(A_LoopField, "Adds \d+?\-\d+? Fire Damage")
        {
            If (ItemSubType == "Amulet" or ItemSubType == "Ring")
            {
                ValueRange := LookupAffixData("data\AddedFireDamage_RingsAndAmulets.txt", ItemLevel)
            }
            Else
            {
                If (ItemSubType == "Gloves")
                {
                    ValueRange := LookupAffixData("data\AddedFireDamage_Gloves.txt", ItemLevel)
                }
                Else
                {
                    If (ItemGripType == "1H") ; one handed weapons
                    {
                        ValueRange := LookupAffixData("data\AddedFireDamage_1H.txt", ItemLevel)
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\AddedFireDamage_2H.txt", ItemLevel)
                    }
                }
            }
            If (ItemQuality > 0)
            {
                ValueRange := AdjustRangeForQuality(ValueRange, ItemQuality)
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        If RegExMatch(A_LoopField, "Adds \d+?\-\d+? Lightning Damage")
        {
            If (ItemSubType == "Amulet" or ItemSubType == "Ring")
            {
                ValueRange := LookupAffixData("data\AddedLightningDamage_RingsAndAmulets.txt", ItemLevel)
            }
            Else
            {
                If (ItemSubType == "Gloves")
                {
                    ValueRange := LookupAffixData("data\AddedLightningDamage_Gloves.txt", ItemLevel)
                }
                Else
                {
                    If (ItemGripType == "1H") ; one handed weapons
                    {
                        ValueRange := LookupAffixData("data\AddedLightningDamage_1H.txt", ItemLevel)
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\AddedLightningDamage_2H.txt", ItemLevel)
                    }
                }
            }
            If (ItemQuality > 0)
            {
                ValueRange := AdjustRangeForQuality(ValueRange, ItemQuality)
            }
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, Physical Damage to Melee Attackers
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\PhysDamageReturn.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Gems in this item
        {
            If (ItemBaseType == "Weapon")
            {
                If (ItemSubType == "Bow")
                {
                    ValueRange := LookupAffixData("data\GemLevel_Bow.txt", ItemLevel)
                }
                Else
                {
                    If (InStr(A_LoopField, "Fire") or InStr(A_LoopField, "Cold") or InStr(A_LoopField, "Lightning"))
                    {
                        ValueRange := LookupAffixData("data\GemLevel_Elemental.txt", ItemLevel)
                    }
                    Else
                    {
                        If (InStr(A_LoopField, "Melee"))
                        {
                            ValueRange := LookupAffixData("data\GemLevel_Melee.txt", ItemLevel)
                        }
                        Else
                        {
                            ; Paragorn's
                            ValueRange := LookupAffixData("data\GemLevel.txt", ItemLevel)
                        }
                    }
                }
            }
            Else
            {
                ValueRange := LookupAffixData("data\GemLevel_Minion.txt", ItemLevel)
            }
            NumPrefixes += 1
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, maximum Life
        {
            ValueRange := LookupAffixData("data\MaxLife.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            NumPrefixes += 1
            Continue
        }
        IfInString, A_LoopField, maximum Mana
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\MaxMana.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Physical Attack Damage Leeched as
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\LifeLeech.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, Movement Speed
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\MovementSpeed.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Spell Damage
        {
            If (ItemSubType == "Amulet")
            {
                ValueRange := LookupAffixData("data\SpellDamage_Amulets.txt", ItemLevel)
            }
            Else
            {
                If (ItemSubType == "Staff")
                {
                    ValueRange := LookupAffixData("data\SpellDamage_Staves.txt", ItemLevel)
                }
                Else
                {
                    ValueRange := LookupAffixData("data\SpellDamage_1H.txt", ItemLevel)
                }
            }
            NumPrefixes += 1
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Elemental Damage with Weapons
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\IncrWeaponElementalDamage.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }

        ; Flask effects (on belts)
        IfInString, A_LoopField, increased Flask Mana Recovery rate
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\FlaskManaRecoveryRate.txt", ItemLevel)
            AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
            Continue
        }
        IfInString, A_LoopField, increased Flask Life Recovery rate
        {
            NumPrefixes += 1
            ValueRange := LookupAffixData("data\FlaskLifeRecoveryRate.txt", ItemLevel)
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

            ; get actual value on ingame tooltip as a number
;            Global ActualValue
            ActualValue := RegExReplace(A_LoopField, "(\d+).*", "$1") ; matches "16% increased Block and Stun Recovery", returns "16"

;            Global ValueRangeArmour
;            Global ArmourHi
;            Global ArmourLo
            ArmourHi := 0
            ArmourLo := 0
            If (InStr(AugmentedStats, "'Armour'"))
            {
                ValueRangeArmour := LookupAffixData("data\StunRecovery_Armour.txt", ItemLevel)
                ParseRange(ValueRangeArmour, ArmourHi, ArmourLo)
            }
;            Global ValueRangeES
;            Global ESHi
;            Global ESLo
            ESHi := 0
            ESLo := 0
            If (InStr(AugmentedStats, "'Energy Shield'"))
            {
                ValueRangeES := LookupAffixData("data\StunRecovery_EnergyShield.txt", ItemLevel)
                ParseRange(ValueRangeES, ESHi, ESLo)
            }
;            Global ValueRangeER
;            Global ERHi
;            Global ERLo
            ERHi := 0
            ERLo := 0
            If (InStr(AugmentedStats, "'Evasion Rating'"))
            {
                ValueRangeER := LookupAffixData("data\StunRecovery_Evasion.txt", ItemLevel)
                ParseRange(ValueRangeER, ERHi, ERLo)
            }
;            Global ValueRangeHybrid
;            Global HybridHi
;            Global HybridLo
            HybridHi := 0
            HybridLo := 0
            If (HasHybridDefences)
            {
                ValueRangeHybrid := LookupAffixData("data\StunRecovery_Hybrid.txt", ItemLevel)
                ParseRange(ValueRangeHybrid, HybridHi, HybridLo)
            }

            ; probably a prefix (but could be a suffix)
            ValueRange := LookupAffixData("data\StunRecovery_Prefix.txt", ItemLevel)
;            Global PrefixHi
;            Global PrefixLo
            PrefixHi := 0
            PrefixLo := 0
            ParseRange(ValueRange, PrefixHi, PrefixLo)
            If ((ActualValue >= PrefixLo) and (ActualValue <= PrefixHi)) 
            {
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
                NumPrefixes += 1
                Continue ; between bounds: all good, don't bother with the rest...
            }

            ValueRange := LookupAffixData("data\StunRecovery_Suffix.txt", ItemLevel)
;            Global SuffixHi
;            Global SuffixLo
            SuffixHi := 0
            SuffixLo := 0
            ParseRange(ValueRange, SuffixHi, SuffixLo)
            If ((ActualValue >= SuffixLo) and (ActualValue <= SuffixHi)) ; between bounds: all good
            {
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
                NumSuffixes += 1
                Continue
            }
            Else
            {
;                Global CompoundHi
;                Global CompoundLo
                ; if any of the complex stun recovery attributes is present we don't need to add 
                ; prefix to suffix after adding the complex attribute range (because that would make
                ; it a compound of a suffix and prefix and a prefix again)
                If ((ArmourLo > 0) or (ESLo > 0) or (ERLo > 0) or (HybridLo > 0))
                {
                    CompoundLo := (SuffixLo + ArmourLo + ESLo + ERLo + HybridLo)
                }
                Else
                {
                    CompoundLo := (PrefixLo + SuffixLo)
                }
                If ((ArmourHi > 0) or (ESHi > 0) or (ERHi > 0) or (HybridHi > 0))
                {
                    CompoundHi := (SuffixHi + ArmourHi + ESHi + ERHi + HybridHi)
                }
                Else
                {
                    CompoundHi := (PrefixHi + SuffixHi)
                }
                ValueRange = %CompoundLo%-%CompoundHi%
                NumSuffixes += 1
                NumPrefixes += 1
                AppendAffixInfo(A_LoopField, "Prefix+Suffix", ValueRange, AffixInfo)
            }
            Continue
        }

        IfInString, A_LoopField, to Accuracy Rating
        {
            AffixType := "Suffix"
            If (HasIncrLightRadius)
            {
                ValueRange := LookupAffixData("data\AccuracyRating_LightRadius.txt", ItemLevel)
                NumSuffixes += 1
            }
            Else
            {
                ; if it is a weapon and has an implicit accuracy mod or PhysDmg is augmented it is a prefix otherwise a suffix
                If (ItemBaseType == "Weapon")
                {
                    ; this is another one of these situations where the type (prefix or suffix) is ambiguous
                    ; as before with block and stun recovery, check for bounds and re-evaluate if neccessary...
                    ActualValue := RegExReplace(A_LoopField, "\+(\d+).*", "$1") ; matches "+113 to Accuracy Rating", returns "113"
                    If (InStr(ImplicitMods, "Accuracy Rating") or InStr(AugmentedStats, "'Physical Damage'"))
                    {
                        ValueRange := LookupAffixData("data\IncrPhysDamage_AccuracyRating.txt", ItemLevel)
                        ARHi := 0
                        ARLo := 0
                        ParseRange(ValueRange, ARHi, ARLo)
                        If ((ActualValue < PrefixLo) or (ActualValue > PrefixHi))
                        {
                            ValueRange := LookupAffixData("data\AccuracyRating_Weapons.txt", ItemLevel)
                            NumSuffixes += 1
                        }
                        Else
                        {
                            ; all good: between bounds
                            NumPrefixes += 1
                            AffixType := "Prefix"
                        }
                    }
                    Else
                    {
                        ValueRange := LookupAffixData("data\AccuracyRating_Weapons.txt", ItemLevel)
                        NumSuffixes += 1
                    }
                }
                Else
                {
                    ; amulets, rings, gloves, helmets and quivers
                    ValueRange := LookupAffixData("data\AccuracyRating_Global.txt", ItemLevel)
                }
            }
            AppendAffixInfo(A_LoopField, AffixType, ValueRange, AffixInfo)
            Continue
        }

        IfInString, A_LoopField, increased Rarity
        {
            If (HasIIQ)
            {
                NumSuffixes += 1
                ValueRange := LookupAffixData("data\IIR_Suffix.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Suffix", ValueRange, AffixInfo)
            }
            Else
            {
                NumPrefixes += 1
                ValueRange := LookupAffixData("data\IIR_Prefix.txt", ItemLevel)
                AppendAffixInfo(A_LoopField, "Prefix", ValueRange, AffixInfo)
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

    Global RarityLevel ; d
    RarityLevel := CheckRarityLevel(ItemDataRarity)

    Global IsFlask ; d
    IsFlask := False
    ; check if the user requests a tooltip for a flask
    IfInString, ItemDataPartsLast, Right click to drink
    {
        IsFlask := True
    }

    Global IsUnique ; d
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
        return ; ItemDataParts doesn't have the parts/text we need. Bail. This might be because the clipboard is empty.
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
        
        ;Fix for Elemental damage only weapons. Like the Oro's Sacrifice
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

        ;global PhysDps
        ;global EleDps
        ;global TotalDps
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

    Global ShowAffixTotals
    If (RarityLevel > 1 and ShowAffixTotals == 1)
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

    Global ShowAffixDetails
    If (Not IsFlask and Not IsUnidentified and ShowAffixDetails = 1)
    {
        TT = %TT%`n--------%AffixInfo%
        If (RarityLevel > 3)
        {
            TT = %TT%`n--------`nUnique items boost some stats beyond rare`nitem ranges
        }
   }

    ; Replaces Clipboard with tooltip data
    ;StringReplace, clipboard, TT, `n, %A_SPACE% , All
    ;SetClipboardContents(ItemDataLast)

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
    If (MouseMoved or ToolTipTimeout >= ToolTipTimeoutTicks) 
    {
        SetTimer, ToolTipTimer, Off
        ToolTip
    }
    return

OnClipBoardChange:
    ParseClipBoardChanges()
