unit functions;

{$mode ObjFPC}{$H+}

{$codepage UTF8}

interface

uses
  Classes, SysUtils, MD5, DateUtils, strutils, nosotime;

function GetPrefix(NumberID:integer):string;
Function HashMD5String(StringToHash:String):String;
Function NosoHashOld(source:string):string;
Function BlockAge():integer;
Function HashrateToShow(speed:int64):String;
Function Parameter(LineText:String;ParamNumber:int64):String;
function Int2Curr(Value: int64): string;
Function UpTime(FromTime:Int64):string;
function IsValid58(base58text:string):boolean;

IMPLEMENTATION

uses
  consominer2unit;

// Returns a valid minning prefix from the specified integer
function GetPrefix(NumberID:integer):string;
var
  firstchar, secondchar : integer;
  HashChars : integer;
Begin
NumberID := NumberID mod 8100;
HashChars :=  length(HasheableChars)-1;
firstchar := NumberID div HashChars;
secondchar := NumberID mod HashChars;
result := HasheableChars[firstchar+1]+HasheableChars[secondchar+1];
End;

Function HashMD5String(StringToHash:String):String;
Begin
result := Uppercase(MD5Print(MD5String(StringToHash)));
end;

Function BlockAge():integer;
Begin
Result := UTCTime mod 600;
End;

// Original nosohash function
Function NosoHashOld(source:string):string;
var
  counter : integer;
  FirstChange : array[1..128] of string;
  finalHASH : string;
  ThisSum : integer;
  charA,charB,charC,charD:integer;
  Filler : string = '%)+/5;=CGIOSYaegk';

  Function GetClean(number:integer):integer;
  Begin
  result := number;
  if result > 126 then
     begin
     repeat
       result := result-95;
     until result <= 126;
     end;
  End;

  function RebuildHash(incoming : string):string;
  var
    counter : integer;
    resultado2 : string = '';
    chara,charb, charf : integer;
  Begin
  for counter := 1 to length(incoming) do
     begin
     chara := Ord(incoming[counter]);
       if counter < Length(incoming) then charb := Ord(incoming[counter+1])
       else charb := Ord(incoming[1]);
     charf := chara+charb; CharF := GetClean(CharF);
     resultado2 := resultado2+chr(charf);
     end;
  result := resultado2
  End;

Begin
result := '';
for counter := 1 to length(source) do
   if ((Ord(source[counter])>126) or (Ord(source[counter])<33)) then
      begin
      source := '';
      break
      end;
if length(source)>63 then source := '';
repeat source := source+filler;
until length(source) >= 128;
source := copy(source,0,128);
FirstChange[1] := RebuildHash(source);
for counter := 2 to 128 do FirstChange[counter]:= RebuildHash(firstchange[counter-1]);
finalHASH := FirstChange[128];
for counter := 0 to 31 do
   begin
   charA := Ord(finalHASH[(counter*4)+1]);
   charB := Ord(finalHASH[(counter*4)+2]);
   charC := Ord(finalHASH[(counter*4)+3]);
   charD := Ord(finalHASH[(counter*4)+4]);
   thisSum := CharA+charB+charC+charD;
   ThisSum := GetClean(ThisSum);
   Thissum := ThisSum mod 16;
   result := result+IntToHex(ThisSum,1);
   end;
Result := HashMD5String(Result);
End;

Function HashrateToShow(speed:int64):String;
Begin
if speed>1000000000 then result := FormatFloat('0.00',speed/1000000000)+' Ghs'
else if speed>1000000 then result := FormatFloat('0.00',speed/1000000)+' Mhs'
else if speed>1000 then result := FormatFloat('0',speed/1000)+' Khs'
else result := speed.ToString+' h/s'
End;

Function Parameter(LineText:String;ParamNumber:int64):String;
var
  Temp : String = '';
  ThisChar : Char;
  Contador : int64 = 1;
  WhiteSpaces : int64 = 0;
  parentesis : boolean = false;
Begin
while contador <= Length(LineText) do
   begin
   ThisChar := Linetext[contador];
   if ((thischar = '(') and (not parentesis)) then parentesis := true
   else if ((thischar = '(') and (parentesis)) then
      begin
      result := '';
      exit;
      end
   else if ((ThisChar = ')') and (parentesis)) then
      begin
      if WhiteSpaces = ParamNumber then
         begin
         result := temp;
         exit;
         end
      else
         begin
         parentesis := false;
         temp := '';
         end;
      end
   else if ((ThisChar = ' ') and (not parentesis)) then
      begin
      WhiteSpaces := WhiteSpaces +1;
      if WhiteSpaces > Paramnumber then
         begin
         result := temp;
         exit;
         end;
      end
   else if ((ThisChar = ' ') and (parentesis) and (WhiteSpaces = ParamNumber)) then
      begin
      temp := temp+ ThisChar;
      end
   else if WhiteSpaces = ParamNumber then temp := temp+ ThisChar;
   contador := contador+1;
   end;
if temp = ' ' then temp := '';
Result := Temp;
End;

function Int2Curr(Value: int64): string;
begin
Result := IntTostr(Abs(Value));
result :=  AddChar('0',Result, 9);
Insert('.',Result, Length(Result)-7);
If Value <0 THen Result := '-'+Result;
end;

Function UpTime(FromTime:Int64):string;
var
  TotalSeconds,days,hours,minutes,seconds, remain : integer;
Begin
Totalseconds := UTCTime-FromTime;
Days := Totalseconds div 86400;
remain := Totalseconds mod 86400;
hours := remain div 3600;
remain := remain mod 3600;
minutes := remain div 60;
remain := remain mod 60;
seconds := remain;
if Days > 0 then Result:= Format('%.2dd%.2dh%.2d', [Days, Hours, Minutes])
else Result:= Format('%.2d:%.2d:%.2d', [Hours, Minutes, Seconds]);
End;

{Verify if a string is a valid Base58 one}
function IsValid58(base58text:string):boolean;
var
  counter : integer;
Begin
  result := true;
  if Length(base58text) = 0 then Exit(False);
  for counter := 1 to length(base58text) do
    if pos (base58text[counter],B58Alphabet) = 0 then
      Exit(false);
End;

END.

