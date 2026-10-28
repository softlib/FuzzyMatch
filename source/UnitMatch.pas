unit UnitMatch;
{
 https://github.com/AliDehbansiahkarbon/FuzzyMatch
}
interface
uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Data.DB, Vcl.Grids, Vcl.DBGrids, System.Generics.Collections,
  Vcl.ComCtrls, Data.Win.ADODB;
type
  TMatchOption = set of (moCaseSensitive, moIgnoreDiacritics, moGreedy);
type
  TFormFuzzy = class(TForm)
    DataSource1: TDataSource;
    Panel1: TPanel;
    Panel2: TPanel;
    lblSearch: TLabel;
    Chk_CaseSensitive: TCheckBox;
    Edt_Search: TEdit;
    Chk_FuzzyMatch: TCheckBox;
    DBGrid1: TDBGrid;
    ADOConnection1: TADOConnection;
    ADOTable1: TADOTable;
    Timer1: TTimer;
    procedure Edt_SearchChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure ADOTable1FilterRecord(DataSet: TDataSet; var Accept: Boolean);
    procedure Edt_SearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    function XPos(APattern, AStr: string; ACaseSensitive: Boolean): Integer;
    function FuzzyMatchStr(const Pattern, Str: string; MatchedIndexes: TList; CaseSensitive: Boolean): Boolean;
    function FuzzyMatchStrEx(const Pattern, Str: string; MatchedIndexes: TList; Options: TMatchOption): Boolean;
    function MatchPattern(const Pattern, Str: string; MatchedIndexes: TList;Options: TMatchOption): Boolean;

    function LowChar(AChar: Char): Char; inline;
    procedure HighlightCellText(AGrid :TDbGrid; const ARect : TRect; Field : TField;  MatchedIndexes : TList; AState:TGridDrawState ; BkColor : TColor = clYellow; SelectedBkColor : TColor = clGray);
    procedure HighlightCellTextFull(AGrid :TDbGrid; const ARect : TRect; Field : TField;  FilterText : string; AState:TGridDrawState ; BkColor : TColor = clYellow; SelectedBkColor : TColor = clGray);
  public
    { Public declarations }
  end;
var
  FormFuzzy: TFormFuzzy;
implementation
uses System.Character;
{$R *.DFM}
// 将字符转换为其“基本字符”（忽略变音符号）并转小写
function GetBaseLowerChar(C: Char): Char;
var
  NormStr: string;
  Src, Dst: PChar;
  SrcLen, DstLen: Integer;
begin
  //使用 Windows API NormalizeString（推荐，支持全部 Unicode）
  //NormalizeString 是 Windows API，位于 Normaliz.dll（Vista 起内置）

  // 准备源字符串（单字符）
  SetLength(NormStr, 1);
  NormStr[1] := C;

  // 第一次调用获取目标缓冲区所需大小
  Src := PChar(NormStr);
  SrcLen := Length(NormStr);
  DstLen := {winapi.}Windows.NormalizeString(NormalizationD, Src, SrcLen, nil, 0);
  if DstLen <= 0 then
    Exit(C);  // 无法规范化，返回原字符

  // 第二次调用进行实际转换
  SetLength(NormStr, DstLen);
  Dst := PChar(NormStr);
  if {winapi.}Windows.NormalizeString(NormalizationD, Src, SrcLen, Dst, DstLen) > 0 then
  begin
    // 规范化后，第一个字符是基本字符，后续字符是组合用变音符号
    if NormStr <> '' then
      Result := NormStr[1]
    else
      Result := C;
  end
  else
    Result := C;

  // 如果是字母，转小写
  if Result.IsLetter then
    Result := Result.ToLower;
end;

procedure TFormFuzzy.ADOTable1FilterRecord(DataSet: TDataSet; var Accept: Boolean);
begin
  if Chk_FuzzyMatch.Checked then
  begin
   // Accept := FuzzyMatchStr(Edt_Search.Text, DataSet.FieldByName('Name').AsString, nil, Chk_CaseSensitive.Checked) ;
    if Chk_CaseSensitive.Checked then
   // Accept := FuzzyMatchStrEx(Edt_Search.Text, DataSet.FieldByName('Name').AsString, nil, [moCaseSensitive, moIgnoreDiacritics])
     Accept := MatchPattern(Edt_Search.Text, DataSet.FieldByName('Name').AsString, nil, [moCaseSensitive, moIgnoreDiacritics,moGreedy]);
  end
  else
    Accept := XPos(Edt_Search.Text, DataSet.FieldByName('Name').AsString, Chk_CaseSensitive.Checked) > 0;
//  Accept := Pos(AnsiLowerCase(Edt_Search.Text), AnsiLowerCase(DataSet.FieldByName('Name').AsString)) > 0;
end;
procedure TFormFuzzy.DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  LvPattern, LvValue: string;
  LvMatchedIndexes: TList;
begin
  if not Assigned(Column.Field) then
    Exit;
  if not Chk_FuzzyMatch.Checked then
  begin
    LvPattern := Trim(Edt_Search.Text);
    HighlightCellTextFull(TDBGrid(Sender),Rect, Column.Field, LvPattern, State);
    Exit;
  end;
  DBGrid1.Canvas.Font.Color := clBlack;
  LvMatchedIndexes := TList.Create;
  try
    if (gdFocused in State) then
    begin
      DBGrid1.Canvas.Brush.Color := clBlack;
      DBGrid1.Canvas.Font.Color := clWhite;
    end
    else if Column.Field.DataType in [ftString, ftInteger, ftFloat, ftCurrency, ftMemo, ftWideString, ftLargeint, ftWideMemo, ftLongWord] then
    begin
      LvPattern := Trim(Edt_Search.Text);
      LvValue := Column.Field.AsString;
     // if FuzzyMatchStr(LvPattern, LvValue, LvMatchedIndexes, Chk_CaseSensitive.Checked) then
      // if FuzzyMatchStrEx(LvPattern, LvValue, LvMatchedIndexes, [moCaseSensitive, moIgnoreDiacritics]) then
       if MatchPattern(LvPattern, LvValue, LvMatchedIndexes, [moCaseSensitive, moIgnoreDiacritics,moGreedy]) then
        HighlightCellText(TDBGrid(Sender),Rect, Column.Field, LvMatchedIndexes, State);
    end
    else
      DBGrid1.Canvas.Brush.Color := clWhite;
  finally
    LvMatchedIndexes.Free;
  end;
end;
procedure TFormFuzzy.Edt_SearchChange(Sender: TObject);
begin
  if Trim(Edt_Search.Text).IsEmpty then
    ADOTable1.Filtered := False
  else
  begin
    ADOTable1.Filtered := False;
    ADOTable1.Filtered := True;
  end;
  DBGrid1.Repaint;

end;
procedure TFormFuzzy.Edt_SearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
 if (ssCtrl in Shift) and (Key=13) then
 begin
    if Trim(Edt_Search.Text).IsEmpty then
      ADOTable1.Filtered := False
    else
    begin
      ADOTable1.Filtered := False;
      ADOTable1.Filtered := True;
    end;
    DBGrid1.Repaint;
 end;

end;

procedure TFormFuzzy.FormCreate(Sender: TObject);
var
  LvDataSourcePath: string;
begin
  LvDataSourcePath := ExtractFilePath(Application.ExeName);
  ADOConnection1.ConnectionString := 'Provider=Microsoft.Jet.OLEDB.4.0;Data Source=' + LvDataSourcePath +
            ';Extended Properties="text;HDR=No;FMT=Delimited";Persist Security Info=False';
 // ADOTable1.TableName := 'Sample.csv';
  //ADOTable1.TableName := 'Sample_ENG.csv';
  ADOTable1.TableName := 'Sample_CHI.csv';
  ADOTable1.Open;
end;
procedure TFormFuzzy.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Ord(key) = 27 then
    Close;
end;
function TFormFuzzy.FuzzyMatchStr(const Pattern: string; const Str: string; MatchedIndexes: TList; CaseSensitive: Boolean): Boolean;
var
  PIdx, SIdx: Integer;
begin
  Result := False;
  if (Pattern = '') or (Str = '') then
    Exit;
  PIdx := 1;
  SIdx := 1;
  if MatchedIndexes <> nil then
    MatchedIndexes.Clear;
  if CaseSensitive then
  begin
    while (PIdx <= Length(Pattern)) and (SIdx <= Length(Str)) do
    begin
      if Pattern[PIdx] = Str[SIdx] then
      begin
        Inc(PIdx);
        if MatchedIndexes <> nil then
          MatchedIndexes.Add(Pointer(SIdx));
      end;
      Inc(SIdx);
    end;
  end
  else
  begin
    while (PIdx <= Length(Pattern)) and (SIdx <= Length(Str)) do
    begin
      if LowChar(Pattern[PIdx]) = LowChar(Str[SIdx]) then
      begin
        Inc(PIdx);
        if MatchedIndexes <> nil then
          MatchedIndexes.Add(Pointer(SIdx));
      end;
      Inc(SIdx);
    end;
  end;
  Result := PIdx > Length(Pattern);
end;

function TFormFuzzy.FuzzyMatchStrEx(const Pattern, Str: string; MatchedIndexes: TList;
  Options: TMatchOption): Boolean;
var
  PIdx, SIdx: Integer;
  PChar, SChar: Char;
  UseCaseSensitive, UseIgnoreDiacritics: Boolean;

  function NormalizeMatchChar(C: Char): Char;
  begin
    Result := C;
    if UseIgnoreDiacritics then
      Result := GetBaseLowerChar(Result);   // 分解变音并转小写

    if not UseCaseSensitive then
      Result :=TCharacter.ToLower(Result);       // 仅转小写
  end;

begin
  Result := False;
  if (Pattern = '') or (Str = '') then
    Exit;

  UseCaseSensitive := moCaseSensitive in Options;
  UseIgnoreDiacritics := moIgnoreDiacritics in Options;

  PIdx := 1;
  SIdx := 1;
  if MatchedIndexes <> nil then
    MatchedIndexes.Clear;

  while (PIdx <= Length(Pattern)) and (SIdx <= Length(Str)) do
  begin
    PChar := NormalizeMatchChar(Pattern[PIdx]);
    SChar := NormalizeMatchChar(Str[SIdx]);

    if PChar = SChar then
    begin
      Inc(PIdx);
      if MatchedIndexes <> nil then
        MatchedIndexes.Add(Pointer(SIdx));
    end;
    Inc(SIdx);
  end;

  Result := PIdx > Length(Pattern);
end;

function TFormFuzzy.LowChar(AChar: Char): Char;
begin
  if AChar in ['A'..'Z'] then
    Result := Chr(Ord(AChar) + 32)
  else
    Result := AChar;
end;
function TFormFuzzy.MatchPattern(const Pattern, Str: string;MatchedIndexes: TList; Options: TMatchOption): Boolean;
var
  PIdx, SIdx: Integer;
  PChar, SChar: Char;
  UseCaseSensitive, UseIgnoreDiacritics, UseGreedy: Boolean;
  TempIndexes: TList;
  i: Integer;

  function NormalizeMatchChar(C: Char): Char;
  begin
    Result := C;
    if UseIgnoreDiacritics then
      Result := GetBaseLowerChar(Result);   // 分解变音并转小写

    if not UseCaseSensitive then
      Result := TCharacter.ToLower(Result); // 仅转小写
  end;

begin
  Result := False;
  if (Pattern = '') or (Str = '') then
    Exit;

  UseCaseSensitive    := moCaseSensitive in Options;
  UseIgnoreDiacritics := moIgnoreDiacritics in Options;
  UseGreedy           := moGreedy in Options;

  if MatchedIndexes <> nil then
    MatchedIndexes.Clear;

  if UseGreedy then
  begin
    // ---------- 贪婪匹配（从后向前）----------
    TempIndexes := TList.Create;
    try
      PIdx := Length(Pattern);
      SIdx := Length(Str);

      while (PIdx >= 1) and (SIdx >= 1) do
      begin
        PChar := NormalizeMatchChar(Pattern[PIdx]);
        SChar := NormalizeMatchChar(Str[SIdx]);

        if PChar = SChar then
        begin
          Dec(PIdx);
          TempIndexes.Add(Pointer(SIdx));   // 记录当前匹配位置（原始索引）
        end;
        Dec(SIdx);
      end;

      Result := PIdx = 0;                    // 所有 Pattern 字符均已匹配
      if Result and (MatchedIndexes <> nil) then
      begin
        // 将记录的位置反转，恢复为从左到右的顺序
        for i := TempIndexes.Count - 1 downto 0 do
          MatchedIndexes.Add(TempIndexes[i]);
      end;
    finally
      TempIndexes.Free;
    end;
  end
  else
  begin
    // ---------- 非贪婪匹配（原有逻辑）----------
    PIdx := 1;
    SIdx := 1;

    while (PIdx <= Length(Pattern)) and (SIdx <= Length(Str)) do
    begin
      PChar := NormalizeMatchChar(Pattern[PIdx]);
      SChar := NormalizeMatchChar(Str[SIdx]);

      if PChar = SChar then
      begin
        Inc(PIdx);
        if MatchedIndexes <> nil then
          MatchedIndexes.Add(Pointer(SIdx));
      end;
      Inc(SIdx);
    end;

    Result := PIdx > Length(Pattern);
  end;
end;

function TFormFuzzy.XPos(APattern, AStr: string; ACaseSensitive: Boolean): Integer;
var
  PIdx, SIdx: Integer;
begin
  Result := 0;
  if (APattern.Trim.IsEmpty) or (AStr.Trim.IsEmpty) then
    Exit;
  if ACaseSensitive then
  begin
    PIdx := 1;
    SIdx := 1;
    while (PIdx <= Length(APattern)) and (SIdx <= Length(AStr)) do
    begin
      if APattern[PIdx] = AStr[SIdx] then
      begin
        Inc(PIdx);
        Result := SIdx;
        Break;
      end;
      Inc(SIdx);
    end;
  end
  else
    Result := Pos(LowerCase(APattern), LowerCase(AStr));
end;
procedure TFormFuzzy.HighlightCellText(AGrid :TDbGrid; const ARect : TRect; Field : TField;  MatchedIndexes : TList; AState:TGridDrawState ; BkColor : TColor = clYellow; SelectedBkColor : TColor = clGray);
var
  LvRectArray: array of TRect;
  I, LvPosition, LvOffset: Integer;
  LvHlText, LvDisplayText: string;
begin
  LvDisplayText := Field.AsString;
  SetLength(LvRectArray, MatchedIndexes.Count);
  for I := 0 to Pred(MatchedIndexes.Count) do
  begin
    LvPosition := Integer(MatchedIndexes.Items[I]);
    if LvPosition > 0 then
    begin
      case Field.Alignment of
        taLeftJustify: LvRectArray[I].Left := ARect.Left + AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, LvPosition - 1)) + 1;
        taRightJustify:
        begin
          LvOffset := AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, 1)) - 1;
          LvRectArray[I].Left :=  (ARect.Right - AGrid.Canvas.TextWidth(LvDisplayText) - LvOffset) + AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, LvPosition - 1));
        end;
        taCenter:
        begin
          LvOffset := ((ARect.Right - ARect.Left) div 2) - (AGrid.Canvas.TextWidth(LvDisplayText) div 2) - (AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, 1)) - 2);
          LvRectArray[I].Left := (ARect.Right - AGrid.Canvas.TextWidth(LvDisplayText) - LvOffset) + AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, LvPosition - 1));
        end;
      end;
      LvRectArray[I].Top := ARect.Top + 1;
      LvRectArray[I].Right := LvRectArray[I].Left + AGrid.Canvas.TextWidth(Copy(LvDisplayText, LvPosition, length(LvDisplayText[LvPosition]))) + 1 ;
      LvRectArray[I].Bottom := ARect.Bottom - 1;
      if LvRectArray[I].Right > ARect.Right then  //check for  limitation of the cell
        LvRectArray[I].Right := ARect.Right;
      if gdSelected in AState then // Setup the color and draw the rectangle in a width of the matching text
        AGrid.Canvas.Brush.Color := SelectedBkColor
      else
        AGrid.Canvas.Brush.Color := BkColor;
      AGrid.Canvas.FillRect(LvRectArray[I]);
      LvHlText := Copy(LvDisplayText,LvPosition, length(LvDisplayText[LvPosition]));
      AGrid.Canvas.TextRect(LvRectArray[I], LvRectArray[I].Left + 1, LvRectArray[I].Top + 1, LvHlText);
    end;
  end;
end;
procedure TFormFuzzy.HighlightCellTextFull(AGrid: TDbGrid; const ARect: TRect; Field: TField; FilterText: string; AState: TGridDrawState ; BkColor : TColor = clYellow; SelectedBkColor : TColor = clGray);
var
  LvHlRect: TRect;
  LvPosition, LvOffset: Integer;
  LvHlText, LvDisplayText: string;
begin
  LvDisplayText := Field.AsString;
  LvPosition := Pos(AnsiLowerCase(FilterText), AnsiLowerCase(LvDisplayText));
  if LvPosition > 0 then
  begin
    case Field.Alignment of
      taLeftJustify: LvHlRect.Left := ARect.Left + AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, LvPosition - 1)) + 1;
      taRightJustify:
      begin
        LvOffset := AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1,1)) - 1;
        LvHlRect.Left :=  (ARect.Right - AGrid.Canvas.TextWidth(LvDisplayText) - LvOffset) + AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, LvPosition - 1));
      end;
      taCenter:
      begin
       LvOffset := ((ARect.Right - ARect.Left) div 2) - (AGrid.Canvas.TextWidth(LvDisplayText) div 2) - (AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1,1)) - 2);
       LvHlRect.Left := (ARect.Right - AGrid.Canvas.TextWidth(LvDisplayText) - LvOffset) + AGrid.Canvas.TextWidth(Copy(LvDisplayText, 1, LvPosition - 1));
      end;
    end;
    LvHlRect.Top    := ARect.Top + 1;
    LvHlRect.Right  := LvHlRect.Left + AGrid.Canvas.TextWidth(Copy(LvDisplayText, LvPosition, Length(FilterText))) + 1 ;
    LvHlRect.Bottom := ARect.Bottom - 1;
    if LvHlRect.Right > ARect.Right then  //check for  limit of the cell
      LvHlRect.Right := ARect.Right;
    if gdSelected in AState then  // setup the color and draw the rectangle in a width of the matching text
      AGrid.Canvas.Brush.Color := SelectedBkColor
    else
      AGrid.Canvas.Brush.Color := BkColor;
    AGrid.Canvas.FillRect(LvHlRect);
    LvHlText := Copy(LvDisplayText,LvPosition, Length(FilterText));
    AGrid.Canvas.TextRect(LvHlRect,LvHlRect.Left + 1, LvHlRect.Top + 1, LvHlText);
  end;
end;
end.
