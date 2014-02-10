Introduction
------------

**PoE Item Info** is a heavily extended version of the PoE Item Level and DPS Revealer script.

The script has been added to substantially to enable the following features in addition to 
itemlevel and weapon DPS reveal:

- show total affix statistic for rare items
- show possible min-max ranges for all affixes on rare items
- reveal the combination of difficult compound affixes (you might be surprised what you find)
- show affix ranges for uniques
- has the ability to convert currency items to chaos orbs (you can adjust the rates by editing
    `data\CurrencyRates.txt`)
- can show which gems are valuable and/or drop-only (all user adjustable)
- adds a system tray icon and proper system tray description tooltip

All of these features are user-adjustable by using a "database" of text files which come 
with the script and are easy to edit by non developers. See header comments in those files
for format infos and data sources.

Requirements
------------

AutoHotkey v1.0.45 or newer. You can get AutoHotkey from http://ahkscript.org/download.  
You can use either the ANSI or the Unicode version if you need to choose.

Known Issues
------------

Even though there have been lots of tests made on composite affix combinations, I expect there
to be odd edge cases still that may return an invalid or not found affix bracket.

You can see these entries in the affix detail lines if they have the text `n/a` (not available)
somewhere in them or if you see an empty range ` - *`.

The star, by the way, marks ranges that have been added together for a guessed attempt as to the 
composition of a possible compound affix.

If you see this star, take a closer look for a moment to check if the projection is correct. 
I expect these edge cases to be properly dealt with over time as the script matures. 

See start of script for some more background info on these issues.

Attribution
-----------

Created by hazydoc / IGN: Sadou

Based on POE_iLVL_DPS-Revealer script (v1.2d) 

See http://www.pathofexile.com/forum/view-thread/594346 for original author info.