{
This file is part of OvoPlayer
Copyright (C) 2011 Marco Caselli

OvoPlayer is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

}
{$I ovoplayer.inc}
unit AudioEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, Song, BaseTypes;

type

  TAudioEngineClass = class of TAudioEngine;

  RAudioEngine = record
    Engine : TAudioEngineClass;
    Name: String;
    Priority : Integer;
    ForceSelection:boolean;
    _Experimental : boolean;
    Failed :boolean;
  end;

  { TAudioEngine }

  TAudioEngine = class
  private
    FInitialized: boolean;
    FOnSongEnd:   TNotifyEvent;
    FOnSongStart: TNotifyEvent;
    FPaused:      boolean;
  protected
    function GetMainVolume: integer; virtual; abstract;
    function GetMaxVolume: integer; virtual; abstract;
    procedure SetMainVolume(const AValue: integer); virtual; abstract;

    function GetSongPos: integer; virtual; abstract;
    procedure SetSongPos(const AValue: integer); virtual; abstract;

    procedure SetOnSongEnd(const AValue: TNotifyEvent);
    procedure SetOnSongStart(const AValue: TNotifyEvent);
    procedure SetPaused(const AValue: boolean);
    function GetState: TEngineState; virtual; abstract;
    Function DoPlay(Song: TSong; offset:Integer):boolean; virtual; abstract;
    procedure ReceivedCommand(Sender: TObject; Command: TEngineCommand; Param: integer = 0); virtual;
    Function GetMuted: boolean; virtual; abstract;
    procedure SetMuted(const AValue: boolean); virtual; abstract;
    // Usually this method do not need overriding
    function GetInitialized: boolean; virtual;
    procedure SetInitialized(AValue: boolean); virtual;
  public
    class Function GetEngineName: string; virtual; abstract;
    Class Function IsAvalaible(ConfigParam: TStrings): boolean; virtual; abstract;
    Class Function GetEngineParamsCount: Integer; virtual;
    Class Function GetEngineParams: AREngineParams; virtual;
    Class Function GetEngineInfo(IsCurrent:boolean): AREngineParams; virtual;

    constructor Create; virtual;
    destructor Destroy; override;

    { Initialize method must be called only once for an engine.
      Resource allocated by this methos should be released in the destroy method
      It return false if initialization of engine fails
      }
    Function Initialize: boolean; virtual; abstract;

    { Activate method usually is called every time a song start playing,
      some engine could be calling it only once...
      }
    procedure Activate; virtual; abstract;
    procedure Play(Song: TSong; offset:Integer=0); virtual;
    function Playing: boolean; virtual; abstract;
    function Running: boolean; virtual; abstract;
    procedure Seek(Seconds: integer; SeekAbsolute: boolean); virtual; abstract;
    procedure Stop; virtual; abstract;
    procedure Pause; virtual;
    procedure UnPause; virtual; abstract;
    procedure PostCommand(Command: TEngineCommand; Param: integer = 0); virtual; abstract;
  public
    property Initialized: boolean read GetInitialized write SetInitialized;
    property Muted: boolean read GetMuted write SetMuted;
    property MainVolume: integer read GetMainVolume write SetMainVolume;
    property OnSongEnd: TNotifyEvent read FOnSongEnd write SetOnSongEnd;
    property OnSongStart: TNotifyEvent read FOnSongStart write SetOnSongStart;
    property Paused: boolean read FPaused write SetPaused;
    property Position: integer read GetSongPos write SetSongPos;
    property State: TEngineState read GetState;
    Property MaxVolume: Integer Read GetMaxVolume;
  end;

Procedure RegisterEngineClass(const EngineClass: TAudioEngineClass;
                              const Priority:Integer;
                              const ForceSelection: boolean = false;
                              const _Experimental:boolean = false);

Function GetEngineByName(const Name: string): TAudioEngineClass;
Procedure SetEngineFailed(const Engine: TAudioEngineClass);

Function GetBestEngine: TAudioEngineClass;

var
  EngineArray : array of RAudioEngine;

implementation
uses LazFileUtils, GeneralFunc, math;

Type
  TEngineSorter = specialize TSortArray<RAudioEngine>;

procedure RegisterEngineClass(const EngineClass: TAudioEngineClass;
                              const Priority: Integer;
                              const ForceSelection: boolean = false;
                              const _Experimental:boolean = false);
var
  EngineRecord : RAudioEngine;
begin
  SetLength(EngineArray, Length(EngineArray) + 1);
  EngineRecord.Engine := EngineClass;
  EngineRecord.Name := Engineclass.GetEngineName;
  EngineRecord.Priority := Priority;
  EngineRecord.ForceSelection:=ForceSelection;
  EngineRecord._Experimental := _Experimental;
  EngineRecord.Failed:= False;
  EngineArray[High(EngineArray)] := EngineRecord;
end;

function GetEngineByName(const Name: string): TAudioEngineClass;
var
  i:integer;
begin
  result:=nil;
  for i := Low(EngineArray) to High(EngineArray) do
    if SameText(EngineArray[i].Name, Name) then
       begin
         Result:= EngineArray[i].Engine;
         break;
       end;

end;

procedure SetEngineFailed(const Engine: TAudioEngineClass);
var
  i: integer;
begin
  for i := Low(EngineArray) to High(EngineArray) do
    if EngineArray[i].Engine = Engine then
       begin
         EngineArray[i].Failed := true;
         break;
       end;
end;

function CompareEngine(const Item1, Item2: Integer): Integer;
  begin
    result := CompareBoolean(EngineArray[item1].Failed,EngineArray[item2].Failed);
    if result = 0 then
       result := CompareValue(EngineArray[item1].Priority,EngineArray[item2].Priority);
  end;

procedure SortEngines;
begin
  TEngineSorter.Sort(EngineArray, @CompareEngine);
end;

function GetBestEngine: TAudioEngineClass;
var
  i:integer;
begin
  SortEngines;
  result:=nil;
  for i := Low(EngineArray) to High(EngineArray) do
    if EngineArray[i].Engine.isAvalaible(nil) and not (EngineArray[i].Failed) then
       begin
         result := EngineArray[i].Engine;
         break;
       end;

end;

{ TAudioEngine }

function TAudioEngine.GetInitialized: boolean;
begin
 result:= FInitialized;
end;

procedure TAudioEngine.SetInitialized(AValue: boolean);
begin
  FInitialized := AValue;
end;

class function TAudioEngine.GetEngineParamsCount: Integer;
begin
  Result := 0;
end;

procedure TAudioEngine.SetOnSongEnd(const AValue: TNotifyEvent);
begin
  if FOnSongEnd = AValue then
    exit;
  FOnSongEnd := AValue;
end;

procedure TAudioEngine.SetOnSongStart(const AValue: TNotifyEvent);
begin
  if FOnSongStart = AValue then
    exit;
  FOnSongStart := AValue;
end;

procedure TAudioEngine.SetPaused(const AValue: boolean);
begin
  if AValue then
    Pause
  else
    UnPause;

end;

procedure TAudioEngine.ReceivedCommand(Sender: TObject;
  Command: TEngineCommand; Param: integer);
begin
  case Command of
    ecNext: if Assigned(fOnSongEnd) then
        fOnSongEnd(Self);

    ecSeek: Seek(Param, True);

    end;
end;

class function TAudioEngine.GetEngineParams: AREngineParams;
begin
  SetLength(result,0);
end;

class function TAudioEngine.GetEngineInfo(IsCurrent:boolean): AREngineParams;
begin
  SetLength(result,0);
end;

constructor TAudioEngine.Create;
begin
  inherited Create;
end;


destructor TAudioEngine.Destroy;
begin
  inherited Destroy;
end;

procedure TAudioEngine.Pause;
begin
 //
end;

procedure TAudioEngine.Play(Song: TSong; offset:Integer=0);
begin
  if Song = nil then
     exit;

  if not FileExistsUTF8( Song.FullName) then
     begin
       PostCommand(ecNext);
       exit;
     end;

  if DoPlay(song, offset) then
     begin
       if Assigned(FOnSongStart) then
         FOnSongStart(self);
     end
  else
    begin
      PostCommand(ecNext);
    end;
end;

initialization
  setlength(EngineArray, 0);
Finalization
  setlength(EngineArray, 0);
end.
