unit netsupport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, base64, BaseTypes, basetag,
  netprotocol;


function EncodeSize(Size:Integer):string;
function DecodeSize(Size:string):integer;

function EncodeImageSize(Width, Height: integer):string;
Procedure DecodeImageSize(Size:string; Out Width, Height: integer);

Function EncodeString(S:String): string;
Function EncodeStream(inStream:TStream):string;

function BuildCommand(Category: string; Command: string; Param:string=''; IPCSeparator:boolean=false):string;
Function SplitCommand(ACommand:string): RExternalCommand;


Function EncodeMetaData(Tags:TCommonTags): String;
Function DecodeMetaData(var StringTags:string): TCommonTags;

Function ExtractField(var StringTags:String ):String;


implementation
uses strutils, LazUTF8;

function EncodeSize(Size:Integer):string;
var
  s : RawByteString;
  v:integer;
begin
  SetLength(s,3);
  s[1] := AnsiChar((Size and $ff0000 ) shr 16);
  s[2] := AnsiChar((Size and $00ff00) shr 8);
  s[3] := AnsiChar((Size and $0000ff));
  Result := base64.EncodeStringBase64(s);
end;

function DecodeSize(Size: String): integer;
var
  s : RawByteString;
  v:integer;
begin
  try
    s:= DecodeStringBase64(Size, True);

    Result := (byte(s[1]) shl 16) or
              (byte(s[2]) shl 8) or
              (byte(s[3]));
  except
    result := -1;
  end;
end;

function EncodeImageSize(Width, Height: integer): string;
begin
  Result := format('%dx%d', [Width, Height]);
end;

Procedure DecodeImageSize(Size: string; out Width, Height: integer);
var
  tmpW: string;
  pX: integer;
begin
  Width:=-1;
  Height:=-1;
  if Length(Size) = 0 then
    exit;

  try
    pX:=pos('x', Size);
    if pX = 0 then
      exit;
    Width:=StrToInt(Copy(Size,1,pX-1));
    Height:=StrToInt(Copy(Size,pX+1, Length(Size) -pX));
  Except
  end;
end;

Function EncodeString(S:String): string;
begin
  Result := EncodeSize(UTF8Length(s))+s;
end;

function BuildCommand(Category: string; Command: string; Param: string;
  IPCSeparator: boolean): string;
begin
  Result := Category +
            CATEGORY_COMMAND_SEPARATOR+
            Command;

  if Param <> '' then
     Result := Result +
               CATEGORY_PARAM_SEPARATOR +
               Param;
  if IPCSeparator then
     Result := Result + IPC_SEPARATOR;
end;

function SplitCommand(ACommand: string): RExternalCommand;
var
  pColon, pEqual: integer;
  tmpstr: string;
  cmdlength: integer;
begin
  Result.Category:=EmptyStr;
  Result.Param:=EmptyStr;
  cmdlength := Length(ACommand);

  if (cmdlength >0 ) and (ACommand[cmdlength] = IPC_SEPARATOR) then
     dec(cmdlength);

  pColon:= pos(CATEGORY_COMMAND_SEPARATOR,ACommand);
  if pColon < 1 then
    Result.Command:=ACommand
  else
    begin
      Result.Category:=copy(ACommand, 1,pColon-1);
      pEqual:= PosEx(CATEGORY_PARAM_SEPARATOR,ACommand,pColon+1);
      if pEqual < 1 then
        Result.Command:=Copy(ACommand,pColon+1, cmdlength)
      else
        begin
           Result.Command:=copy(ACommand, pColon+1,pEqual -pColon -1);
           Result.Param:= copy(ACommand, pEqual+1, cmdlength);
        end;
    end;
end;

Function ExtractField(var StringTags:String ):String;
var
  size: integer;
begin
  size:= DecodeSize(Copy(StringTags,1,4));
  Result := copy(StringTags, 5, size);
  inc(size,4);
  Delete(StringTags, 1, size);
end;

function EncodeMetaData(Tags: TCommonTags): String;
begin
  result := EncodeString(   // is this encoding really needed ??? Maybe only for check
                EncodeString(inttostr(Tags.id))+
                EncodeString(Tags.FileName)+
                EncodeString(Tags.Album)+
                EncodeString(Tags.AlbumArtist)+
                EncodeString(Tags.Artist)+
                EncodeString(Tags.Comment)+
                EncodeString(Inttostr(Tags.Duration))+
                EncodeString(Tags.Genre)+
                EncodeString(Tags.Title)+
                EncodeString(Tags.TrackString)+
                EncodeString(Tags.Year)
           );
end;

function DecodeMetaData(var StringTags: string): TCommonTags;
var
  tmp: string;
begin
  Delete(StringTags, 1, 4);

  Result.ID          := StrToInt64Def(ExtractField(StringTags),0);
  Result.FileName    := ExtractField(StringTags);
  Result.Album       := ExtractField(StringTags);
  Result.AlbumArtist := ExtractField(StringTags);
  Result.Artist      := ExtractField(StringTags);
  Result.Comment     := ExtractField(StringTags);
  Result.Duration    := StrToInt64Def(ExtractField(StringTags),0);
  Result.Genre       := ExtractField(StringTags);
  Result.Title       := ExtractField(StringTags);
  Result.TrackString := ExtractField(StringTags);
  Result.Year        := ExtractField(StringTags);

end;

Function EncodeStream(inStream:TStream):string;
var
  Encoder: TBase64EncodingStream;
  Outstream : TStringStream;
begin
  Result := EmptyStr;

  if not Assigned(inStream) then
    exit;

  if inStream.Size = 0 then
    exit;

  Outstream:=TStringStream.Create('');
  try
    Encoder := TBase64EncodingStream.Create(Outstream);
    try
      inStream.Position:=0;
      Encoder.CopyFrom(inStream, inStream.Size);
    finally
      Encoder.Free;
      end;
    Result:=Outstream.DataString;
  finally
    Outstream.free;
  end;

end;




end.



