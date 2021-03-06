#NoEnv
#WinActivateForce
#SingleInstance force
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2

#Persistent
OnExit, ExitSub

Menu, Tray, NoStandard
Menu, Tray, Add, Open Settings, OpenSettings
Menu, Tray, Add, Reload Settings, LoadSettings
Menu, Tray, Add, Debug, Debug
Menu, Tray, Add
Menu, Tray, Add, Exit, ExitSub

; Init Vars
global Artist, Track
settings_file := "settings.ini"
now_playing_file := "output\NowPlaying.txt"
album_art := "output\Cover.png"
temp_json_file := "tmp\temp.json"
artist_json_file := "tmp\artist.json"
was_playing := ""

Gosub, LoadSettings

SetTimer, CheckSong, 500
Return

CheckSong:
	WinGetTitle, playing, ahk_class SpotifyMainWindow
	StringTrimLeft, playing, playing, 10
	if (was_playing != playing)
	{
		; Save playing song to check for changes
		was_playing := playing
		; Remove Spotify's pesky Original Mix suffix
		if InStr(playing, "- Original Mix")
			playing := RegExReplace(playing, "- Original Mix", "")
		; Prepend whitespace for scrolling	
		playing_formatted := "      " . playing
		FileDelete %now_playing_file%
		FileAppend, %playing_formatted%, %now_playing_file%, UTF-8
		if StrLen(was_playing) > 0
		{
			GoSub, GetSongInfo
			Menu, Tray, Tip, %Artist% - %Track%
		}
		Else
		{
			Menu, Tray, Tip, Paused.
		}
		
	}
	Return

GetSongInfo:
	; Retrieve song's json info from last.fm api
	Url := "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=" lastfm_user "&api_key=" api_key "&format=json"
	URLDownloadToFile, % Url, % temp_json_file
	FileRead, j, % temp_json_file
	Artist := UnJson(json(j, "recenttracks.track[0].artist.#text"))
	Track := UnJson(json(j, "recenttracks.track[0].name"))
	album_art_url := UnJson(json(j, "recenttracks.track[0].image[3].#text"))
	DebugLog(Artist . "`n" . Track . "`n" . album_art_url)
	; If no album art found for song, try to retrieve from artist
	If StrLen(album_art_url) < 1
	{
		DebugLog("Song track art not found.")
		Url_Artist := "http://ws.audioscrobbler.com/2.0/?method=artist.getInfo&artist=" Artist "&api_key=" api_key "&format=json"
		URLDownloadToFile, % Url_Artist , % artist_json_file
		FileRead, a, % artist_json_file
		album_art_url := UnJson(json(a, "artist.image[3].#text"))
		If StrLen(album_art_url) < 1
		{
			DebugLog("Artist art found.")
			URLDownloadToFile, % album_art_url, % album_art
			source := "Source: Artist Info"
		}
		Else
		{
			DebugLog("No Art Found")
			source := "Source: No Image Found"
			FileCopy, img\Unknown.png, % album_art, 1
		}
	}
	Else
	{
		source := "Source: Recent Tracks"
		URLDownloadToFile, % album_art_url, % album_art
	}
	if Notification
		Notify(Artist . " - " . Track, source,-4,"Style=Fast IW=128 IH=128 Image=" album_art)
	Return

UnJson(string)
{
	return % RegExReplace(string, "\\/", "/")
}

OpenSettings:
	Run % settings_file
	Return

LoadSettings:
	If FileExist(settings_file)
	{
		path := ini_load(ini, settings_file)
		lastfm_user := ini_getValue(ini, Settings, "User")
		api_key := ini_getValue(ini, Settings, "API_Key")
		Notification := ini_getValue(ini, Settings, "Notification")
	}
	Else
	{
		Msgbox, Config ini not found!
		ExitApp
	}
	Return

Debug:
    If (Debug := !Debug)
        Notify("Debugging Enabled",,-3,"Style=Warn")
    else
        Notify("Debugging Disabled",,-3,"Style=Warn")
    Menu, Tray, ToggleCheck, Debug
Return



ExitSub:
	FileDelete % album_art
	FileDelete % now_playing_file
	FileDelete % temp_json_file
	FileDelete % artist_json_file
	ExitApp
	Return

#Include %A_ScriptDir%\lib\json.ahk
#Include %A_ScriptDir%\lib\ini.ahk
#Include %A_ScriptDir%\lib\Notify.ahk

DebugLog(text)
{
	global
	If Debug
	{
		FormatTime, Now,, M/dd [h:mm:ss]
    	FileAppend, %Now%`n%text%`n, %NetworkFolder%debug.txt
    }
}