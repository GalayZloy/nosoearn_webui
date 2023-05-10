unit noso_miner;

{$mode ObjFPC}{$H+}

interface

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, StrUtils,
  NosoDig.Crypto, NosoDig.Crypto68b, NosoDig.Crypto68, NosoDig.Crypto65,
  functions, consominer2unit, NosoTime;

Type
  TMiner = class
  public
    Procedure RunMiner();
  end;

  TMinerThread = class(TThread)
  private
    TNumber: integer;
  protected
    procedure Execute; override;
  public
    Constructor Create(CreateSuspended: boolean; const Thisnumber:integer);
  end;

  TMainThread = class(TThread)
  protected
    procedure Execute; override;
  public
    constructor Create(CreateSuspended : boolean);
  end;

  TNosoHashFn = function(S: String): THash32;

  THashLibs = (hl65, hl68, hl69, hl70);

  TNosoHashLib = packed record
    Name: String;
    HashFn: TNosoHashFn;
  end;

Const
  NOSOHASH_LIBS: array[THashLibs] of TNosoHashLib =
    (
    (Name: 'NosoHash v65'; HashFn: @NosoHash65),
    (Name: 'NosoHash v68'; HashFn: @NosoHash68),
    (Name: 'NosoHash v69'; HashFn: @NosoHash68b),
    (Name: 'NosoHash v70'; HashFn: @NosoHash)
    );

var
  MainThread: TMainThread;
  MinerThread: TMinerThread;
  CurrHashLib: THashLibs;

implementation

Constructor TMinerThread.Create(CreateSuspended: boolean; const Thisnumber: integer);
Begin
  inherited Create(CreateSuspended);
  Tnumber := ThisNumber;
  FreeOnTerminate := True;
End;

procedure TMinerThread.Execute;
var
  BaseHash, ThisDiff : string;
  ThisHash : string = '';
  ThisSolution : TSolution;
  MyID : integer;
  ThisPrefix : string = '';
  MyCounter : int64 = 100000000;
  EndThisThread : boolean = false;
  ThreadBest  : string = '00000FFFFFFFFFFFFFFFFFFFFFFFFFFF';
Begin
if MyRunTest then MinimunTargetDiff := '00000';
MyID := TNumber-1;
ThisPrefix := MAINPREFIX+GetPrefix(MyID);
ThisPrefix := AddCharR('!',ThisPrefix,18);
ThreadBest := AddCharR('F',MinimunTargetDiff,32);
While ((not FinishMiners) and (not EndThisThread)) do
   begin
   BaseHash := ThisPrefix+MyCounter.ToString;
   Inc(MyCounter);
   ThisHash := NOSOHASH_LIBS[CurrHashLib].HashFn(BaseHash+PoolMinningAddress);
   ThisDiff := GetHashDiff(TargetHash,ThisHash);
   if ThisDiff<ThreadBest then
      begin
      ThisSolution.Target:=TargetHash;
      ThisSolution.Hash  :=BaseHash;
      ThisSolution.Diff  :=ThisDiff;
      if not MyRunTest then
         begin
         if ThisHash = NosoHashOld(BaseHash+PoolMinningAddress) then
            begin
            AddSolution(ThisSolution);
            end;
         end;
      end;
   if MyRunTest then
      begin
      if MyCounter >= 100000000+HashesForTest then EndThisThread := true;
      end
   else
      begin
      if MyCounter mod 1000 = 999 then AddIntervalHashes(1000);
      end;
   end;
DecreaseOMT;
End;

Procedure LaunchMiners();
var
  SourceResult : integer;
  Counter      : integer;
Begin
ToLog('Syncing...');
Repeat
   SourceResult := CheckSource;
   If SourceResult=0 then sleep(1000);
until SourceResult>0;
if SourceResult=2 then exit;
U_Headers := true;
ResetIntervalHashes;
FinishMiners := false;
WrongThisPool := 0;
ClearSolutions();
LastSpeedCounter := 100000000;
for counter := 1 to MyCPUCount do
  begin
    MinerThread := TMinerThread.Create(true,counter);
    MinerThread.FreeOnTerminate:=true;
    MinerThread.Start;
    sleep(1);
  end;
SetOMT(MyCPUCount);
U_ActivePool := true;
End;

constructor TMainThread.Create(CreateSuspended : boolean);
Begin
  inherited Create(CreateSuspended);
  FreeOnTerminate := true;
End;

procedure TMainThread.Execute;
Begin
While not FinishProgram do
   begin
   CheckLog;
   if SolutionsLength > 0 then
      SendPoolShare(GetSolution);
   if ( (blockage>=585) and (Not WaitingNextBlock) ) then
      begin
      FinishMiners     := true;
      WaitingNextBlock := true;
      U_WaitNextBlock  := true;
      ToLog('Started waiting next block');
      UpdateOffset(NTPServers);
      end;
   if ( (blockAge>=10) and (blockage<585) ) then
      begin
      if WaitingNextBlock then
         begin
         WaitingNextBlock := false;
         ClearAllPools();
         U_ClearPoolsScreen := true;
         BlockCompleted := false;
         ActivePool := RandonStartPool;
         U_WaitNextBlock := true;
         end
      else
         begin
         if AllFilled then
            begin
            if not BlockCompleted then
               begin
               BlockCompleted := true;
               ToLog('All filled on block ' + CurrentBlock.ToString);
               end;
            end
         else
            begin
            if GetOMTValue = 0 then
               begin
               ToLog('Launching miners...');
               LaunchMiners();
               end
            else
               begin
               //ToLog('Something went wrong...');
               end;
            end;
         end
      end;
   sleep(10);
   end;
MainThreadIsFinished := true;
End;

Procedure TMiner.RunMiner();
Begin
  MyRunTest := false;
  FinishProgram := false;
  WaitingNextBlock := false;
  LoadSources();
  GetTimeOffset(NTPServers);
  MinerStartUTC := UTCTime;
  if Myhashlib = 65 then CurrHashLib := hl65
  else if Myhashlib = 68 then CurrHashLib := hl68
  else if Myhashlib = 69 then CurrHashLib := hl69
  else CurrHashLib := hl70;
  //UpdateHeader;
  //Drawpools;

  ActivePool := RandonStartPool;
  MainThread := TMainThread.Create(true);
  MainThread.FreeOnTerminate:=true;
  MainThread.Start;

  ReadLn;
  FinishMiners := true;
  FinishProgram := true;
  MAinThreadIsFinished := false;
  FinishProgram := false;
  WaitingNextBlock := false;
End;

end.

