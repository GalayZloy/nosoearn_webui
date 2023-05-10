Program nosoearn_webui;

{$mode objfpc}{$H+}

Uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  consominer2unit, noso_webui, noso_miner;

var
  Miner: TMiner;

Begin
  Randomize();
  if not FileExists('nosoearn.cfg') then CreateConfig(true);
  if not FileExists('log.txt') then CreateLogFile();
  if not FileExists('payments.dat') then CreatePaymentsFile();
  if not FileExists('payments.txt') then CreateRAWPaymentsFile();
  LoadConfig();
  if SourcesStr = '' then SourcesStr := DefaultSources;
  LoadSources();
  CreateConfig();
  LoadPreviousPayments;
  WebUI := TWebUI.Create;
  WebUI.Start;
  Miner := Tminer.Create;
  Miner.RunMiner();
End.

