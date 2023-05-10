unit consominer2unit;

{$mode ObjFPC}{$H+}

{$codepage UTF8}

interface

uses
  Classes, SysUtils, strutils,
  IdTCPClient, IdGlobal, IdException, UTF8Process,
  functions, nosotime;

Type

   TSourcesData = packed record
     ip         : string;
     port       : integer;
     Shares     : integer;
     filled     : boolean;
     balance    : int64;
     payinterval: integer;
     FailedTrys : integer;
     miners     : integer;
     fee        : integer;
     LastPay    : string;
     MaxShares  : integer;
     end;

   TPayment = packed record
     Pool     : string[30];
     block    : integer;
     ammount  : int64;
     OrderID  : string[60];
     end;

   TSolution = Packed record
     Hash   : string;
     Target : string;
     Diff   : string;
     end;

   TMsgType = Packed Record
     info: String;
     error: String;
   end;

Procedure LoadSources();
Function GetPoolInfo(PoolIp:String;PoolPort:integer):String;
Function GetPoolSource(Ip:String;Port:integer):String;
Procedure SendPoolShare(Data:TSolution);
Function RandonStartPool():integer;
Function AllFilled():Boolean;
Procedure FillAllPools();
Procedure ClearAllPools();
Function GetTotalPending():Int64;
Procedure SaveSource(LSource:TSourcesData);
Procedure SetStatusMsg(StatusMsg: String; TypeMsg: String);
// Disk access
Procedure CreateConfig(ByDefault : boolean = false);
Procedure LoadConfig();
Function CheckSource():integer;
// Log manage
Procedure CreateLogFile();
Procedure Tolog(LLine:String);
Procedure CheckLog();
// Payments
Procedure CreatePaymentsFile();
Procedure CreateRAWPaymentsFile();
Function GetPoolLastPay(PoolName:String):String;
Procedure LoadPreviousPayments();
Procedure AddNewPayment(LData:Tpayment);

//*************
Procedure AddSolution(Data:TSolution);
Function SolutionsLength():Integer;
function GetSolution():TSolution;
Procedure ClearSolutions();
Procedure AddIntervalHashes(hashes:int64);
function GetTotalHashes : integer;
Procedure ResetIntervalHashes();
Procedure SetOMT(value:integer);
Procedure DecreaseOMT();
Function GetOMTValue():Integer;

Const
  AppVer            = '2.1';
  ReleaseDate       = 'Apr 15, 2023';
  HasheableChars    = '!"#$%&'#39')*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
  DeveloperAddress  = 'N3VXG1swUP3n46wUSY5yQmqQiHoaDED';
  NTPServers        = 'ts2.aco.net:hora.roa.es:time.esa.int:time.stdtime.gov.tw:stratum-1.sjc02.svwh.net:ntp1.sp.se:1.de.pool.ntp.org:';
  fpcVersion        = {$I %FPCVERSION%};
  B58Alphabet : string = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  MsgType: TMsgType = (info: 'info'; error: 'error');

var
  ArrSources    : Array of TSourcesData;
  MainThreadIsFinished : boolean = false;
  DefaultSources : string = 'pool.nosofish.xyz:8082 pool.noso-akkarin.com:8082 nosopool.estripa.online:8082 pool.nosomn.com:8082 47.87.181.190:8082';

  strMsgStatus: String;
  strMsgType: String;
  strMsgLog: String;

  SourcesStr    : string = '';
  ArrLogLines   : array of string;
  FinishProgram : boolean = false;
  MAXCPU        : integer = 0;
  CurrentBlock  : integer = 0;
  CurrSpeed     : integer = 0;
  CurrBlockAge  : integer = 0;
  ActivePool    : integer = 0;
  //StatusMsg     : string = '';
  //StatusColor   : integer;
  TimeOffSet    : integer = 0;
  // Files vars
  FileConfig      : Textfile;
  FileLog         : Textfile;
  FilePayments    : file of TPayment;
  FileRAWPayments : Textfile;
  // USer config
  MyAddress            : string = 'NpryectdevepmentfundsGE';
  MyCPUCount           : integer = 1;
  MyHAshlib            : integer = 70;
  MyRunTest            : boolean  = True;
  MyMaxShares          : integer = 0;
  MyDonation           : integer = 5;
  MyPassword           : string = 'mypasswrd';
  // Miner Variables
  MyAddressBalance      : int64 = 0;
  ArrHashLibs           : array[0..3] of integer;
  MinerStartUTC         : int64 = 0;
  ReceivedPayments      : integer = 0;
  ReceivedNOSO          : int64 = 0;
  MAINPREFIX            : string = '';
  MinimunTargetDiff     : string = '00000';
  TargetHash            : string = '00000000000000000000000000000000';
  FinishMiners          : boolean = false;
  HashesForTest         : integer = 100000;
  ArrSolutions             : Array of TSolution;
  ThreadsIntervalHashes : integer = 0;
  OpenMinerThreads      : integer = 0;
  LastSpeedCounter      : int64 = 100000000;
    PoolMinningAddress  : string = '';
    WaitingNextBlock    : boolean = false;
    BlockCompleted      : boolean = false;
    WrongThisPool       : Integer = 0;
  // Update screen
  U_Headers            : boolean = false;
  U_BlockAge           : int64 = 0;
  U_ActivePool         : boolean = false;
  U_ClearPoolsScreen   : boolean = false;
  U_WaitNextBlock      : boolean = false;
  U_AddressNosoBalance : boolean = false;
  U_TotalPending       : boolean = false;
  U_NewPayment         : int64 = 0;

  // Crititical sections
  CS_Log          : TRTLCriticalSection;
  CS_ArrSources   : TRTLCriticalSection;
  CS_Solutions    : TRTLCriticalSection;
  CS_Interval     : TRTLCriticalSection;
  CS_MinerThreads : TRTLCriticalSection;

implementation

Function GetPoolInfo(PoolIp: String; PoolPort: Integer): String;
Var
  TCPClient : TidTCPClient;
  ResultLine : String = '';
Begin
  Result := 'ERROR';
  ResultLine := '';
  TCPClient := TidTCPClient.Create(nil);
  TCPclient.Host := PoolIp;
  TCPclient.Port := PoolPort;
  TCPclient.ConnectTimeout := 1000;
  TCPclient.ReadTimeout := 1000;
  Try
    TCPclient.Connect;
    TCPclient.IOHandler.WriteLn('POOLINFO');
    ToLog('GetPoolInfo: ' + PoolIp + ':' + PoolPort.ToString);
    ResultLine := TCPclient.IOHandler.ReadLn();
    TCPclient.Disconnect();
  Except
    on E: EIdConnClosedGracefully do ToLog('Pool closed connection.');
    on E: Exception do ToLog('Error: ' + E.Message);
  End;
  TCPClient.Free;
  If ResultLine <> '' Then Result := ResultLine;
  ToLog('Result: ' + Result);
End;

Function GetPoolSource(Ip: String; Port: Integer): String;
Var
  TCPClient: TidTCPClient;
  ResultLine: String = '';
Begin
  Result := 'ERROR';
  ResultLine := '';
  TCPClient := TidTCPClient.Create(nil);
  TCPclient.Host:=IP;
  TCPclient.Port:=Port;
  TCPclient.ConnectTimeout:= 3000;
  TCPclient.ReadTimeout:=3000;

  Try
    TCPclient.Connect;
    TCPclient.IOHandler.WriteLn('SOURCE ' + MyAddress + ' Cm2' + AppVer + ' ' + HashMD5String(mypassword + Myaddress + TCPclient.Host));
    ToLog('GetPoolSource: ' + 'SOURCE ' + MyAddress + ' Cm2' + AppVer + ' ' + HashMD5String(mypassword+Myaddress+TCPclient.Host));
    ResultLine := TCPclient.IOHandler.ReadLn(IndyTextEncoding_UTF8);
    TCPclient.Disconnect();
    Except
      on E: EIdConnClosedGracefully do ToLog('Pool closed connection.');
      on E: Exception do ToLog('Error: ' + E.Message);
    End;
  TCPClient.Free;
  if Parameter(ResultLine, 0)='OK' then Result := ResultLine;
  ToLog('Result: ' + Result);
End;

Procedure SendPoolShare(Data:TSolution);
var
  TCPClient     : TidTCPClient;
  IpandPor      : String = '';
  ResultLine    : String = '';
  Trys          : integer = 0;
  Success       : boolean;
  CreditAddress : String = '';
Begin
Randomize;
if ( (MyDonation>0) and ((Random(100)+1)<=MyDonation) ) then
   CreditAddress := DeveloperAddress;
ResultLine := '';
TCPClient := TidTCPClient.Create(nil);
TCPclient.Host:=ArrSources[ActivePool].ip;
TCPclient.Port:=ArrSources[ActivePool].port;
TCPclient.ConnectTimeout:= 3000;
TCPclient.ReadTimeout:=3000;
REPEAT
Success := false;
Inc(Trys);
TRY
TCPclient.Connect;
TCPclient.IOHandler.WriteLn('SHARE '+Myaddress+' '+Data.Hash+' Cm2v'+AppVer+' '+CurrentBlock.ToString+' '+Data.target+' '+CreditAddress+' '+HashMD5String(mypassword+Myaddress+TCPclient.Host));
ResultLine := TCPclient.IOHandler.ReadLn(IndyTextEncoding_UTF8);
TCPclient.Disconnect();
Success := true;
EXCEPT on E:Exception do
   begin
   Success := false;
   ToLog('Error sending share: '+E.Message);
   end;
END{try};
UNTIL ((Success) or (Trys = 5));
TCPClient.Free;
if Success then
   begin
   if resultLine = 'True' then
      begin
      Inc(ArrSources[ActivePool].shares);
      U_ActivePool := true;
      SetStatusMsg('Submmited share ' + IntToStr(ArrSources[ActivePool].shares) + ' to ' + ArrSources[ActivePool].ip + ':' + IntToStr(ArrSources[ActivePool].port), MsgType.info);
      if ArrSources[ActivePool].shares >= ArrSources[ActivePool].MaxShares then
         begin
         ArrSources[ActivePool].filled:=true;
         ClearSolutions();
         Sleep(100);
         FinishMiners := true;
         end;
      end
   else
      begin
      SetStatusMsg('Rejected share : ' + ResultLine, 'error');
      Inc(WrongThisPool);
      // Filter here if Shares limit was reached
      If ((AnsiContainsStr(ResultLine,'SHARES_LIMIT')) or ( WrongThisPool = 3)) then
         begin
         ClearSolutions();
         Sleep(10);
         FinishMiners := true;
         if AnsiContainsStr(ResultLine,'SHARES_LIMIT') then ArrSources[ActivePool].filled:=true;
         end;
      end;
   end
else // Not send
   begin
   ToLog('Unable to send solution to '+TCPclient.Host);
   SetStatusMsg('Connection error. Check your internet connection: ' + WrongThisPool.ToString, 'error');
   Inc(WrongThisPool);
   if WrongThisPool = 3 then
      begin
      FinishMiners := true;
      ArrSources[ActivePool].filled:=true;
      ClearSolutions();
      end;
   //AddSolution(Data);
   end;
End;

Procedure LoadSources();
var
  ThisSource : string;
  Counter : integer = 0;
  AlreadyLoaded : string = '';
Begin
SetLength(ArrSources,0);
Repeat
   begin
   ThisSource := Parameter(SourcesStr,counter);
   If ( (ThisSource<> '') and (Not AnsiContainsStr(Uppercase(AlreadyLoaded),Uppercase(ThisSource))) ) then
      begin
      ThisSource := StringReplace(ThisSource,':',' ',[rfReplaceAll, rfIgnoreCase]);
      SetLength(ArrSources,length(ArrSources)+1);
      ArrSources[length(ArrSources)-1].ip:=Parameter(ThisSource,0);
      ArrSources[length(ArrSources)-1].port:=StrToIntDef(Parameter(ThisSource,1),8082);
      ArrSources[length(ArrSources)-1].filled:=false;
      ArrSources[length(ArrSources)-1].shares:=0;
      ArrSources[length(ArrSources)-1].balance:=0;
      ArrSources[length(ArrSources)-1].payinterval:=0;
      ArrSources[length(ArrSources)-1].FailedTrys:=0;
      ArrSources[length(ArrSources)-1].Miners:=0;
      ArrSources[length(ArrSources)-1].Fee:=0;
      ArrSources[length(ArrSources)-1].LastPay:=GetPoolLastPay(Parameter(ThisSource,0));
      ArrSources[length(ArrSources)-1].maxshares:=MyMaxShares;
      AlreadyLoaded := AlreadyLoaded + ThisSource;
      end;
   Inc(Counter);
   end;
until ThisSource = '';
End;

Function RandonStartPool():integer;
Begin
result := Random(Length(ArrSources))-1;
End;

Function AllFilled():Boolean;
var
  counter : integer;
Begin
result := true;
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
    begin
    if ArrSources[counter].filled = false then
       begin
       result := false;
       break;
       end;
    end;
LeaveCriticalSection(CS_ArrSources);
End;

Procedure FillAllPools();
var
  counter : integer;
Begin
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
   ArrSources[counter].filled := true;
LeaveCriticalSection(CS_ArrSources);
End;

Procedure ClearAllPools();
var
  counter : integer;
Begin
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
   begin
   ArrSources[counter].filled     := false;
   ArrSources[counter].Shares     := 0;
   ArrSources[counter].FailedTrys := 0;
   ArrSources[counter].Miners     := 0;
   ArrSources[counter].Fee        := 0;
   end;
LeaveCriticalSection(CS_ArrSources);
End;

Function GetTotalPending():Int64;
var
  counter : integer;
Begin
Result := 0;
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
   Inc(Result,ArrSources[counter].balance);
LeaveCriticalSection(CS_ArrSources);
End;

Procedure SaveSource(LSource:TSourcesData);
var
  counter : integer;
Begin
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
    begin
    if ArrSources[counter].ip = LSource.ip then
       begin
       ArrSources[counter] := LSource;
       break;
       end;
    end;
LeaveCriticalSection(CS_ArrSources);
End;

Procedure SetStatusMsg(StatusMsg: String; TypeMsg: String);
Begin
  strMsgStatus := StatusMsg;
  strMsgType := TypeMsg;
End;

Procedure CreateConfig(ByDefault : boolean = false);
var
  counter : integer;
Begin
TRY
rewrite(FileConfig);
writeln(FileConfig,'** Replace the default mining address with your own address. Aliases not allowed.');
writeln(FileConfig,'address '+MyAddress);
writeln(FileConfig,'** Set the number of CPUs/Threads you want use to mine.');
writeln(FileConfig,'cpu '+MyCPUCount.ToString);
writeln(FileConfig,'** Valid values: 65,68,69 and 70 (default).');
writeln(FileConfig,'hashlib '+MyHashLib.ToString);
writeln(FileConfig,'** Change to false to start mining when you launch the app.');
writeln(FileConfig,'test '+BoolToStr(MyRunTest,true));
writeln(FileConfig,'** Max number of shares to be submitted to each pool. Use 0 to use pool defined.');
writeln(FileConfig,'maxshares '+MyMaxShares.ToString);
writeln(FileConfig,'** Enter a valid number between 0-99 as your % volunteer donation for developer.');
writeln(FileConfig,'donate '+MyDonation.ToString);
writeln(FileConfig,'** Enter your password to be identified by the pools. 8-16 Base58 chars length.');
writeln(FileConfig,'password '+MyPassword);
writeln(FileConfig,'** Enter one earning pool per line on format IPv4:port. None to use default');
if bydefault then
   begin
   writeln(FileConfig,'pool pool.nosofish.xyz:8082');
   writeln(FileConfig,'pool pool.noso-akkarin.com:8082');
   writeln(FileConfig,'pool nosopool.estripa.online:8082');
   writeln(FileConfig,'pool pool.nosomn.com:8082');
   writeln(FileConfig,'pool 47.87.181.190:8082');
   end
else
  begin
  for counter := 0 to length(ArrSources)-1 do
     writeln(FileConfig,'pool '+ArrSources[counter].ip+':'+ArrSources[counter].port.ToString);
  end;
CloseFile(FileConfig);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure LoadConfig();
var
  linea : string;
Begin
TRY
reset(FileConfig);
while not eof(FileConfig) do
   begin
   readln(FileConfig,linea);
   if uppercase(Parameter(linea,0)) = 'ADDRESS' then MyAddress := Parameter(linea,1);
   if uppercase(Parameter(linea,0)) = 'CPU' then MyCPUCount := StrToIntDef(Parameter(linea,1),1);
   if uppercase(Parameter(linea,0)) = 'HASHLIB' then MyHashLib := StrToIntDef(Parameter(linea,1),70);
   if uppercase(Parameter(linea,0)) = 'TEST' then MyRunTest := StrToBoolDef(Parameter(linea,1),false);
   if uppercase(Parameter(linea,0)) = 'MAXSHARES' then MyMaxShares := StrToIntDef(Parameter(linea,1),9999);
   if MyMaxShares < 1 then MyMaxShares := 9999;
   if uppercase(Parameter(linea,0)) = 'DONATE' then MyDonation := StrToIntDef(Parameter(linea,1),5);
   if uppercase(Parameter(linea,0)) = 'PASSWORD' then MyPassword := Parameter(linea,1);
   if uppercase(Parameter(linea,0)) = 'POOL' then SourcesStr := SourcesStr+Parameter(linea,1)+' ';
   end;
CloseFile(FileConfig);
Trim(SourcesStr);
EXCEPT ON E:EXCEPTION do
   begin
   ToLog('Error accessing data file: '+E.Message);
   exit
   end
END {TRY};
End;

Function CheckSource():integer;
var
  ReachedNodes: integer = 0;
  ThisSource: TSourcesData;
  PoolString: String = '';
  PoolPayStr: String = '';
  PoolPayData: TPayment;
  SourceNoso: Int64;
Begin
Result := 0;
Repeat
   Inc(ActivePool);
   if ActivePool >= length(ArrSources) then ActivePool := 0;
until not ArrSources[ActivePool].filled;
ThisSource := ArrSources[ActivePool];
ToLog('CheckSource: ' + ThisSource.ip + ':' + IntToStr(ThisSource.port));
PoolString := GetPoolSource(ThisSource.ip, ThisSource.port);
if PoolString <> 'ERROR' then // Pool reached
   begin
   result := 1;
   MAINPREFIX             := Parameter(PoolString,1);
   PoolMinningAddress     := Parameter(PoolString,2);
   TargetHash             := Parameter(PoolString,4);
   CurrentBlock           := StrToIntDef(Parameter(PoolString,5),0);
   ThisSource.balance     := StrToInt64Def(Parameter(PoolString,6),0);
   ThisSource.payinterval := StrToIntDef(Parameter(PoolString,7),0);
   PoolPayStr          := Parameter(PoolString,8);
   PoolPayStr          := StringReplace(PoolPayStr,':',' ',[rfReplaceAll, rfIgnoreCase]);
   PoolPayData.Pool    := ThisSource.ip;
   PoolPayData.block   := StrToIntDef(Parameter(PoolPayStr,0),0);
   PoolPayData.ammount := StrToInt64Def(Parameter(PoolPayStr,1),0);
   PoolPayData.OrderID := Parameter(PoolPayStr,2);

   if ((PoolPayData.OrderID <> GetPoolLastPay(ThisSource.ip)) and (PoolPayData.ammount>0)) then
      begin
      AddNewPayment(PoolPayData);
      Inc(ReceivedPayments);
      Inc(ReceivedNoso,PoolPayData.ammount);
      U_NewPayment := PoolPayData.ammount;
      end;

   ThisSource.miners      := StrToIntDef(Parameter(PoolString,13),0);
   ThisSource.fee         := StrToIntDef(Parameter(PoolString,14),0);
   SourceNoso             := StrToInt64Def(Parameter(PoolString,15),-1);
   ThisSource.MaxShares   := StrToIntDef(Parameter(PoolString,16),MyMaxShares);
   If SourceNoso>-1 then
      Begin
      MyAddressBalance := SourceNoso;
      U_AddressNosoBalance := true;
      end;
   U_TotalPEnding := true;
   SaveSource(ThisSource);
   SetStatusMsg('Synced with pool ' + ThisSource.ip + ':' + IntToStr(ThisSource.port), 'info');
   end
else
   begin
   Inc(ArrSources[ActivePool].FailedTrys);
   Tolog('Connection error. Check your internet connection');
   if ArrSources[ActivePool].FailedTrys >= 5 then
      begin
      ArrSources[ActivePool].filled:=true;
      result := 2;
      end
   else SetStatusMsg('Failed connecting to ' + ThisSource.ip + ':' + IntToStr(ThisSource.port) + '(' + IntToStr(ArrSources[ActivePool].FailedTrys) + ')', 'error');
   end;
End;

Procedure CreatePaymentsFile();
Begin
TRY
   rewrite(FilePayments);
   CloseFile(FilePayments);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure CreateRAWPaymentsFile();
var
  FirstLine : string;
Begin
TRY
   rewrite(FileRAWPayments);
   FirstLine := (Format(' %-17s | %10s | %12s | %-60s |',['Pool','Block','Amount','OrderID']));
   WriteLn(FileRAWPayments,FirstLine);
   CloseFile(FileRAWPayments);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};

End;

Function GetPoolLastPay(PoolName:String):String;
var
  Counter  : integer;
  ThisData : TPayment;
Begin
Result := '';
TRY
   reset(FilePayments);
   For counter := Filesize(FilePayments)-1 downto 0 do
      begin
      Seek(FilePayments,counter);Read(FilePayments,ThisData);
      if ThisData.Pool=PoolName then
         begin
         Result := ThisData.OrderID;
         break;
         end;
      end;
   CloseFile(FilePayments);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure LoadPreviousPayments();
var
  Counter  : integer;
  ThisData : TPayment;
Begin
TRY
   reset(FilePayments);
   For counter := Filesize(FilePayments)-1 downto 0 do
      begin
      Seek(FilePayments,counter);Read(FilePayments,ThisData);
      Inc(ReceivedPayments);
      Inc(ReceivedNoso,ThisData.ammount);
      end;
   CloseFile(FilePayments);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure AddNewPayment(LData:Tpayment);
var
  RawLine : String;
Begin
TRY
   reset(FilePayments);
   Seek(FilePayments,FileSize(FilePayments));
   Write(FilePayments,Ldata);
   CloseFile(FilePayments);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
TRY
   Append(FileRAWPayments);
   if Length(LData.Pool)>16 then SetLength(Ldata.Pool,16);
   RawLine := (Format(' %-17s | %10s | %12s | %-60s |',[LData.pool,IntToStr(LData.block),Int2Curr(LData.ammount),LData.OrderID]));
   WriteLn(FileRAWPayments,RawLine);
   CloseFile(FileRAWPayments);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure CreateLogFile();
Begin
TRY
   rewrite(FileLog);
   CloseFile(FileLog);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure Tolog(LLine:String);
Var
  t: String;
Begin
  t := Concat(FormatDateTime('dd.mm.YYYY HH:MM:SS.zzz', Now), ' > ', LLine);
  EnterCriticalSection(CS_Log);
  Insert(t, ArrLogLines, Length(ArrLogLines));
  LEaveCriticalSection(CS_Log);
  Writeln(t);
End;

Procedure CheckLog();
Begin
EnterCriticalSection(CS_Log);
If length(ArrLogLines) > 0 then
   begin
   TRY
   Append(FileLog);
   While Length(ArrLogLines)>0 do
      begin
      WriteLn(FileLog,ArrLogLines[0]);
      Delete(ArrLogLines,0,1);
      end;
   CloseFile(FileLog);
   EXCEPT ON E:EXCEPTION DO
      //WriteLn(E.Message);
   END; {Try}
   end;
LeaveCriticalSection(CS_Log);
End;

Procedure AddSolution(Data:TSolution);
Begin
EnterCriticalSection(CS_Solutions);
Insert(Data,ArrSolutions,length(ArrSolutions));
LeaveCriticalSection(CS_Solutions);
End;

Function SolutionsLength():Integer;
Begin
EnterCriticalSection(CS_Solutions);
Result := length(ArrSolutions);
LeaveCriticalSection(CS_Solutions);
End;

function GetSolution():TSolution;
Begin
result := Default(TSolution);
EnterCriticalSection(CS_Solutions);
if length(ArrSolutions)>0 then
   begin
   result := ArrSolutions[0];
   delete(ArrSolutions,0,1);
   end;
LeaveCriticalSection(CS_Solutions);
End;

Procedure ClearSolutions();
Begin
EnterCriticalSection(CS_Solutions);
Setlength(ArrSolutions,0);
LeaveCriticalSection(CS_Solutions);
End;

Procedure AddIntervalHashes(hashes:int64);
Begin
EnterCriticalSection(CS_Interval);
ThreadsIntervalHashes := ThreadsIntervalHashes+hashes;
LeaveCriticalSection(CS_Interval);
End;

function GetTotalHashes : integer;
Begin
EnterCriticalSection(CS_Interval);
Result := ThreadsIntervalHashes;
ThreadsIntervalHashes := 0;
LeaveCriticalSection(CS_Interval);
End;

Procedure ResetIntervalHashes();
Begin
EnterCriticalSection(CS_Interval);
ThreadsIntervalHashes := 0;
LeaveCriticalSection(CS_Interval);
End;

Procedure SetOMT(value:integer);
Begin
EnterCriticalSection(CS_MinerThreads);
OpenMinerThreads := value;
LeaveCriticalSection(CS_MinerThreads);
End;

Procedure DecreaseOMT();
Begin
EnterCriticalSection(CS_MinerThreads);
OpenMinerThreads := OpenMinerThreads-1;
LeaveCriticalSection(CS_MinerThreads);
End;

Function GetOMTValue():Integer;
Begin
EnterCriticalSection(CS_MinerThreads);
Result := OpenMinerThreads;
LeaveCriticalSection(CS_MinerThreads);
End;


Initialization
  MaxCPU := {$IFDEF UNIX} GetSystemThreadCount {$ELSE} GetCPUCount {$ENDIF};

  Assignfile(FileConfig, 'nosoearn.cfg');
  Assignfile(FileLog, 'log.txt');
  Assignfile(FilePayments, 'payments.dat');
  Assignfile(FileRAWPayments, 'payments.txt');

  ArrHashLibs[0]:=65;
  ArrHashLibs[1]:=68;
  ArrHashLibs[2]:=69;
  ArrHashLibs[3]:=70;

  InitCriticalSection(CS_Log);
  InitCriticalSection(CS_ArrSources);
  InitCriticalSection(CS_Solutions);
  InitCriticalSection(CS_Interval);
  InitCriticalSection(CS_MinerThreads);

  SetLength(ArrSolutions,0);
  SetLength(ArrLogLines,0);

Finalization
  DoneCriticalSection(CS_Log);
  DoneCriticalSection(CS_ArrSources);
  DoneCriticalSection(CS_Solutions);
  DoneCriticalSection(CS_Interval);
  DoneCriticalSection(CS_MinerThreads);

END. // END UNIT

