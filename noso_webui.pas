unit noso_webui;

{$mode ObjFPC}{$H+}

{$codepage UTF8}

interface

uses
  Classes, SysUtils, fpjson, jsonparser,
  IdHTTPServer, IdContext, IdCustomHTTPServer, IdStack,
  consominer2unit, functions, nosotime;

type
  TWebUI = class
  private
    FHTTPServer: TIdHTTPServer;
    procedure HandleCommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    function LoadHtml: String;
    function LoadLog: String;
    procedure CreateJsonUpdate;
    function Update: String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  end;

const
  strError = 'ERROR';

var
  WebUI: TWebUI;
  strHtml: String;
  objJsonUpdate: TJSONObject;
  intPoolsCount: Integer;

implementation

function GetIP: String;
begin
  TIdStack.IncUsage;
  try
    Result := GStack.LocalAddress;
  finally
    TIdStack.DecUsage;
  end;
end;

constructor TWebUI.Create;
begin
  try
    FHTTPServer := TIdHTTPServer.Create;
    FHTTPServer.Bindings.Clear;
    FHTTPServer.Bindings.Add;
    FHTTPServer.Bindings[0].IP := GetIP;
    FHTTPServer.Bindings[0].Port := 8083;
    FHTTPServer.Bindings.Add;
    FHTTPServer.Bindings[1].IP := '127.0.0.1';
    FHTTPServer.Bindings[1].Port := 8083;
    intPoolsCount := Length(ArrSources);
    SetStatusMsg('WebUI initialized', MsgType.info);
    strHtml := LoadHtml;
    objJsonUpdate := TJSONObject.Create;
    CreateJsonUpdate;
    FHTTPServer.OnCommandGet := @HandleCommandGet;
  except
    ToLog('Failed to create Web UI');
  end;
end;

destructor TWebUI.Destroy;
begin
  objJsonUpdate.Free;
  FHTTPServer.Free;
  inherited;
end;

procedure TWebUI.HandleCommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  //hcGET, hcPOST, hcHEAD
  if ARequestInfo.CommandType = hcGET then
  begin
    if ARequestInfo.Document = '/' then
    begin
      AResponseInfo.ResponseNo := 200;
      AResponseInfo.ContentType := 'text/html';
      AResponseInfo.ContentLanguage := 'en-US';
      AResponseInfo.CharSet := 'utf-8';
      AResponseInfo.ContentText := strHtml;
    end
    else
      if ARequestInfo.Document = '/update' then
      begin
        AResponseInfo.ResponseNo := 200;
        AResponseInfo.ContentType := 'application/json';
        AResponseInfo.CharSet := 'utf-8';
        AResponseInfo.ContentText := Update;
      end
      else
        if ARequestInfo.Document = '/logfile' then
        begin
          AResponseInfo.ResponseNo := 200;
          AResponseInfo.ContentType := 'text/html';
          AResponseInfo.ContentLanguage := 'en-US';
          AResponseInfo.CharSet := 'utf-8';
          AResponseInfo.ContentText := LoadLog;
        end
        else
        begin
          AResponseInfo.ResponseNo := 404;
          AResponseInfo.ContentType := 'text/html';
          AResponseInfo.ContentText := strError;
        end;
  end;
end;

function TWebUI.LoadHtml: String;
var
  lstHtml: TStringList;
  i: Integer;
  strPool: String = '';
begin
  lstHtml := TStringList.Create;

  try
    lstHtml.LoadFromFile('index.html');

    for i := 0 to intPoolsCount - 1 do
    begin
      strPool := strPool +
        '<tr>' +
        '<td id="pool' + IntToStr(i) + '">' + ArrSources[i].ip + ':' + IntToStr(ArrSources[i].port) + '</td>' +
        '<td id="miners' + IntToStr(i) + '">' + IntToStr(ArrSources[i].miners) + '</td>' +
        '<td id="fee' + IntToStr(i) + '">' + IntToStr(ArrSources[i].fee) + '</td>' +
        '<td id="balance' + IntToStr(i) + '">' + Int2Curr(ArrSources[i].balance) + '</td>' +
        '<td id="pay' + IntToStr(i) + '">' + ArrSources[i].LastPay + '</td>' +
        '<td id="shares' + IntToStr(i) + '">' + IntToStr(ArrSources[i].Shares) + '/' + IntToStr(ArrSources[i].MaxShares) + '</td>' +
        '</tr>';
    end;

    lstHtml.Text := StringReplace(lstHtml.Text, '%appver%', AppVer, []);
    lstHtml.Text := StringReplace(lstHtml.Text, '%address%', MyAddress, []);
    lstHtml.Text := StringReplace(lstHtml.Text, '%cpus%', intToStr(MyCPUCount) + '/' + IntToStr(MAXCPU), []);
    lstHtml.Text := StringReplace(lstHtml.Text, '%library%', intToStr(MyHashLib), []);
    lstHtml.Text := StringReplace(lstHtml.Text, '%donation%', intToStr(MyDonation) + '%', []);
    lstHtml.Text := StringReplace(lstHtml.Text, '%pools%', strPool, []);

    Result := lstHtml.Text;
  except
    on E: Exception do
    begin
      ToLog('Error: ' + E.Message);
      Result := strError;
    end;
  end;
  lstHtml.Free;
end;

function TWebUI.LoadLog: String;
var
  lstLog: TStringList;
  i: Integer;
begin
  lstLog := TStringList.Create;
  EnterCriticalSection(CS_Log);
  try
    lstLog.LoadFromFile('log.txt');
    //loading log.txt and adding strings from ArrLogLines that not yet wrote to log.txt
    for i := 0 to Length(ArrLogLines) - 1 do lstLog.Add(ArrLogLines[i]);
    Result := lstLog.Text;
  except
    on E: Exception do
    begin
      ToLog('Error: ' + E.Message);
      Result := strError;
    end;
  end;
  LEaveCriticalSection(CS_Log);
  lstLog.Free;
end;

procedure TWebUI.CreateJsonUpdate;
var
  i: Integer;
  ThisPool : String;
begin
  objJsonUpdate.Add('balance', '0.00000000');
  objJsonUpdate.Add('payments', ' ');
  objJsonUpdate.Add('received', ' ');
  objJsonUpdate.Add('uptime', ' ');
  objJsonUpdate.Add('now', ' ');
  objJsonUpdate.Add('block', '' );
  objJsonUpdate.Add('age', ' ');
  objJsonUpdate.Add('speed', ' ');
  objJsonUpdate.Add('sum', ' ');
  objJsonUpdate.Add('msgStatus', ' ');
  objJsonUpdate.Add('msgType', 'info');
  objJsonUpdate.Add('msgLog', '...');

  for i := 0 to intPoolsCount - 1 do
  begin
    ThisPool := GetPoolInfo(ArrSources[i].ip, ArrSources[i].port);
    objJsonUpdate.Add('pool' + IntToStr(i), ArrSources[i].ip + ':' + IntToStr(ArrSources[i].port));
    objJsonUpdate.Add('miners' + IntToStr(i), Parameter(ThisPool, 0));
    objJsonUpdate.Add('fee' + IntToStr(i), FormatFloat('0.00', StrToIntDef(Parameter(ThisPool,2),0)/100));
    objJsonUpdate.Add('balance' + IntToStr(i), Int2Curr(ArrSources[i].balance));
    objJsonUpdate.Add('pay' + IntToStr(i), IntToStr(ArrSources[i].payinterval));
    objJsonUpdate.Add('shares' + IntToStr(i), IntToStr(ArrSources[i].Shares) + '/' + IntToStr(ArrSources[i].MaxShares));
  end;
end;

function TWebUI.Update: String;
var
  i: Integer;
begin
  try
    objJsonUpdate.Strings['balance'] := Int2Curr(MyAddressBalance);
    objJsonUpdate.Strings['payments'] := IntToStr(ReceivedPayments);
    objJsonUpdate.Strings['received'] := Int2Curr(ReceivedNoso);
    objJsonUpdate.Strings['uptime'] := Uptime(MinerStartUTC);
    objJsonUpdate.Strings['now'] := TimestampToDate(UTCTime);
    objJsonUpdate.Strings['block'] := IntToStr(CurrentBlock);
    objJsonUpdate.Strings['age'] := IntToStr(CurrBlockAge);
    objJsonUpdate.Strings['speed'] := HashrateToShow(CurrSpeed);
    objJsonUpdate.Strings['donation'] := IntToStr(MyDonation);
    objJsonUpdate.Strings['sum'] := IntToStr(MyAddressBalance);
    objJsonUpdate.Strings['msgStatus'] := strMsgStatus;
    objJsonUpdate.Strings['msgType'] := strMsgType;
    objJsonUpdate.Strings['msgLog'] := strMsgLog;

    for i := 0 to intPoolsCount - 1 do
    begin
      objJsonUpdate.Strings['pool' + IntToStr(i)] := ArrSources[i].ip + ':' + IntToStr(ArrSources[i].port);
      objJsonUpdate.Strings['miners' + IntToStr(i)] := IntToStr(ArrSources[i].miners);
      objJsonUpdate.Strings['fee' + IntToStr(i)] := FormatFloat('0.00', (ArrSources[i].fee / 100.0));
      objJsonUpdate.Strings['balance' + IntToStr(i)] := Int2Curr(ArrSources[i].balance);
      objJsonUpdate.Strings['pay' + IntToStr(i)] := IntToStr(ArrSources[i].payinterval);
      objJsonUpdate.Strings['shares' + IntToStr(i)] := IntToStr(ArrSources[i].Shares) + '/' + IntToStr(ArrSources[i].MaxShares);
    end;

    Result := objJsonUpdate.AsJSON;
  except
    on E: Exception do
    begin
      ToLog('Error: ' + E.Message);
      objJsonUpdate.Strings['msg'] := strError;
      objJsonUpdate.Strings['type'] := 'error';
      Result := objJsonUpdate.AsJSON;
    end;
  end;
end;

procedure TWebUI.Start;
begin
  try
    FHTTPServer.Active := True;
    ToLog('Web UI has started: ' + 'http://' + FHTTPServer.Bindings[0].IP + ':' + IntToStr(FHTTPServer.Bindings[0].Port));
  except
    on E: Exception do ToLog('Failed to start Web UI: ' + E.Message);
  end;
end;

procedure TWebUI.Stop;
begin
  FHTTPServer.Active := False;
end;

end.

