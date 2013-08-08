unit Parser;

interface

uses Generics;

type

    PParserSymbol = ^TParserSymbol;
    TParserSymbol = object( TGeneric)
    private
        Identifier: Word;
{$IFDEF DEBUGSTATE}
        Title: PString;
{$ENDIF}
    public
{$IFDEF DEBUGSTATE}
        constructor Create( AID: Word; ATitle: string);
{$ELSE}
        constructor Create( AID: Word);
{$ENDIF}
        destructor Destroy; virtual;
        function GetID: Word;
{$IFDEF DEBUGSTATE}
        function GetTitle: string;
{$ENDIF}
        end;

    PRule = ^TRule;
    TRule = object( TGeneric)
    private
       ReduceInfo: PGeneric;
       LeftSide: PParserSymbol;
       RightSide: TCollection;
    public
       constructor Create;
       destructor Destroy;virtual;
       procedure SetLeftSymbol( ASymbol: PParserSymbol);
       procedure AppendRightSymbol( ASymbol: PParserSymbol);
       function GetLeftSymbol: PParserSymbol;
       function GetRightSymbol( AIndex:Integer):PParserSymbol;
       function GetRightSideSize: Integer;
       function GetFirstRightSymbol: PParserSymbol;
       function GetNextRightSymbol: PParserSymbol;
       procedure SetReduceInfo( AInfo: PGeneric);
       function GetReduceInfo: PGeneric;
       end;

    PGrammar = ^TGrammar;
    TGrammar = object( TGeneric)
    private
       Rules: TContainerCollection;
    public
       constructor Create;
       destructor Destroy; virtual;
       procedure Clear;
       procedure AppendRule( ARule: PRule);
       function GetRule( AIndex: Integer): PRule;
       function GetRulesCount: Integer;
       function GetFirstRule: PRule;
       function GetNextRule: PRule;
       end;

    PCoreItem = ^TCoreItem;
    TCoreItem = object(TGeneric)
    private
       Rule: PRule;
       Cursor: Integer;
    public
       constructor Create( ARule: PRule; ACursor: Integer);
       function GetRule: PRule;
       function GetCursor: Integer;
       function GetCursorSymbol: PParserSymbol;
       function SameAs( AItem: PCoreItem): Boolean;
       end;

    PSetItem = ^TSetItem;
    TSetItem = object( TCoreItem)
    private
       Marked: Boolean;
       ShiftState: Integer;
    public
       constructor Create( ARule: PRule; ACursor: Integer);
       procedure SetShiftState(AState: Integer);
       function GetShiftState: Integer;
       procedure Mark;
       procedure Unmark;
       function IsMarked: Boolean;
       end;

    PSet = ^TSet;
    TSet = object( TGeneric)
    private
       Identifier: Integer;
       Core: TContainerCollection;
       Items: TContainerCollection;
       procedure MoveItemsToCore( ACoreItems: PCollection);
    public
       constructor Create;
       destructor Destroy;virtual;
       procedure AddCoreItem( ACoreItem: PCoreItem);
       procedure SetID( AIdentifier : Integer);
       function GetID: Integer;
       procedure ExpandSet( AGrammar : PGrammar);
       function CreateCoreCollection( ASymbol: PParserSymbol): PContainerCollection;
       function CompareCoreWith( ACoreItems: PCollection): Boolean;
       function GetFirstCoreItem: PCoreItem;
       function GetNextCoreItem: PCoreItem;
       function GetFirstSetItem: PSetItem;
       function GetNextSetItem: PSetItem;
       function GetUnmarkedSymbol: PParserSymbol;
       procedure MarkSymbol( ASymbol: PParserSymbol; AShiftState: Integer);
       end;

    PSetCollection = ^TSetCollection;
    TSetCollection = object( TGeneric)
    private
       Sets: TContainerCollection;
       function GetSameCoreSet( ACoreItems: PCollection): PSet;
    public
       constructor Create;
       destructor Destroy; virtual;
       procedure Build( AGrammar: PGrammar);
       function GetNumStates: Integer;
       function GetSet( AIndex: Integer): PSet;
{$IFDEF DEBUGSTATE}
       procedure Display;
{$ENDIF}
       end;

    PStackItem = ^TStackItem;
    TStackItem = object( TGeneric)
    private
       State: Word;
       Symbol: PParserSymbol;
       Attribute:  PGeneric;
    public
       constructor Create( AState: Word; ASymbol: PParserSymbol; AAttribute: PGeneric);
       destructor Destroy; virtual;
       function GetState: Word;
       function GetSymbol: PParserSymbol;
       function GetAttribute: PGeneric;
       function ReleaseAttribute: PGeneric;
       end;

    PParserStack = ^TParserStack;
    TParserStack = object( TGeneric)
    private
       Items: TContainerCollection;
    public
       constructor Create;
       destructor Destroy; virtual;
       procedure Clear;
       function Push( AState: Word; ASymbol: PParserSymbol; AAttribute: PGeneric): Boolean;
       function Pop( var AState: Word; var ASymbol: PParserSymbol; var AAttribute: PGeneric): Boolean;
       function SymbolAtTop( ADistance: Word): PParserSymbol;
       function TopState: Word;
       function Size: Word;
{$IFDEF DEBUGSTATE}
       procedure Display;
{$ENDIF}
       end;

    PReduceManager = ^TReduceManager;
    TReduceManager = object( TGeneric)
    private
       Rules: TCollection;
    public
       constructor Create;
       destructor Destroy; virtual;
       procedure AppendRule( AReduceRule: PRule);
       function GetNumRules: Integer;
       function GetRule( AIndex: Integer): PRule;
       function GetReduceRule( ATranslateStack: PParserStack): PRule;
       end;

    PSymbolCol = ^TSymbolCol;
    TSymbolCol = array[ 1..1] of Word;

    PTableCols = ^TTableCols;
    TTableCols = array[ 1..1] of PSymbolCol;

    PReduceInfoTable = ^TReduceInfoTable;
    TReduceInfoTable = array[ 1..1] of PReduceManager;

    PTable = ^TTable;
    TTable = record
       SymbolsCount: Word;
       StatesCount: Word;
       ShiftsTable: PTableCols;
       ReduceInfoTable: PReduceInfoTable;
       end;

    PParserTable = ^TParserTable;
    TParserTable = object( TGeneric)
    private
       Table: TTable;
       procedure FreeTable;
       procedure AllocateTable( ASymbolsCount, AStatesCount: Word);
       procedure BuildTableFromCollection( ASetCollection: PSetCollection; ASymbolsCount: Word);
    public
       constructor Create;
       destructor Destroy;virtual;
       function Build( AGrammar: PGrammar; ASymbolsCount: Word): Boolean;
       function IsTableExist: Boolean;
       function GetStatesCount: Word;
       function GetSymbolsCount: Word;
       function GetNextState( AState: Word; ASymbolId: Word): Word;
       function AnyReduceAtState( AState: Word): Boolean;
       function GetReduceInfo( AState: Word): PReduceManager;
       end;

    PParser = ^TParser;
    TParser = object( TErrGeneric)
    private
       Table: TParserTable;
       Stack: TParserStack;
       Counter: LongInt;
       ReducedSymbolsAttributes: TContainerCollection;
    public
       Symbols: PCollection;
       Grammar: PGrammar;

       constructor Create( AOwner: PErrGeneric; ASymbols: PCollection; AGrammar: PGrammar);
       destructor Destroy;virtual;
       function BuildParser: Boolean;
       procedure ReduceByRule( ARule: PRule);
       procedure GenerateOutput( ARule: PRule; AAttributes: PCollection); virtual;
       function InitTranslation: Boolean;
       function DoneTranslation: Boolean;
       function TakeNextSymbol( ASymbol: PParserSymbol; ASymbolAttr: PGeneric): Boolean;
{$IFDEF DEBUGSTATE}
       procedure DesplayParserTable;
{$ENDIF}
       end;

implementation

{$IFDEF DEBUGSTATE}
constructor TParserSymbol.Create( AID: Word; ATitle: string);
{$ELSE}
constructor TParserSymbol.Create( AID: Word);
{$ENDIF}
begin
     inherited Create;
     Identifier := AID;
{$IFDEF DEBUGSTATE}
     Title := AllocateString( ATitle);
{$ENDIF}
end;

destructor TParserSymbol.Destroy;
begin
{$IFDEF DEBUGSTATE}
     FreeString( Title);
{$ENDIF}
     inherited Destroy;
end;

function TParserSymbol.GetID: Word;
begin
     GetID := Identifier;
end;

{$IFDEF DEBUGSTATE}
function TParserSymbol.GetTitle: string;
begin
     if ( Title <> nil)
     then GetTitle := Title^
     else GetTitle := '';
end;
{$ENDIF}


constructor TRule.Create;
begin
     inherited Create;
     LeftSide := nil;
     RightSide.Create;
     ReduceInfo := nil;
end;

destructor TRule.Destroy;
begin
     RightSide.Destroy;
     inherited Destroy;
end;

procedure TRule.SetLeftSymbol( ASymbol: PParserSymbol);
begin
     LeftSide := ASymbol;
end;

procedure TRule.AppendRightSymbol( ASymbol: PParserSymbol);
begin
     if ( ASymbol <> nil)
     then RightSide.PushLast( ASymbol);
end;

function TRule.GetLeftSymbol: PParserSymbol;
begin
     GetLeftSymbol := LeftSide;
end;

function TRule.GetRightSymbol( AIndex: Integer): PParserSymbol;
begin
     GetRightSymbol := PParserSymbol( RightSide.GetByIndex( AIndex));
end;

function TRule.GetRightSideSize: Integer;
begin
     GetRightSideSize := RightSide.GetItemsCount;
end;

function TRule.GetFirstRightSymbol: PParserSymbol;
begin
     GetFirstRightSymbol := PParserSymbol( RightSide.GetFirst);
end;

function TRule.GetNextRightSymbol: PParserSymbol;
begin
     GetNextRightSymbol := PParserSymbol( RightSide.GetNext);
end;

procedure TRule.SetReduceInfo( AInfo: PGeneric);
begin
     ReduceInfo := AInfo;
end;

function TRule.GetReduceInfo: PGeneric;
begin
     GetReduceInfo := ReduceInfo;
end;


constructor TGrammar.Create;
begin
     inherited Create;
     Rules.Create;
end;

destructor TGrammar.Destroy;
begin
     Rules.Destroy;
     inherited Destroy;
end;

procedure TGrammar.Clear;
begin
     Rules.Clear;
end;

procedure TGrammar.AppendRule( ARule: PRule);
begin
     if ( ARule <> nil)
     then Rules.PushLast( ARule);
end;

function TGrammar.GetRule( AIndex: Integer): PRule;
begin
     GetRule := PRule( Rules.GetByIndex( AIndex));
end;

function TGrammar.GetRulesCount: Integer;
begin
     GetRulesCount := Rules.GetItemsCount;
end;

function TGrammar.GetFirstRule: PRule;
begin
     GetFirstRule := PRule( Rules.GetFirst);
end;

function TGrammar.GetNextRule: PRule;
begin
     GetNextRule := PRule( Rules.GetNext);
end;


constructor TCoreItem.Create( ARule: PRule; ACursor: Integer);
begin
     inherited Create;
     Rule := ARule;
     Cursor := ACursor;
end;

function TCoreItem.GetRule: PRule;
begin
     GetRule := Rule;
end;

function TCoreItem.GetCursor: Integer;
begin
     GetCursor := Cursor;
end;

function TCoreItem.GetCursorSymbol: PParserSymbol;
begin
     if Rule <> nil
     then GetCursorSymbol := Rule^.GetRightSymbol( Cursor)
     else GetCursorSymbol := nil;
end;

function TCoreItem.SameAs( AItem: PCoreItem): Boolean;
begin
     if (AItem <> nil)
     then SameAs := (( Cursor = AItem^.Cursor) and ( Rule = AItem^.Rule))
     else SameAs := False;
end;


constructor TSetItem.Create( ARule: PRule; ACursor: Integer);
begin
     inherited Create(ARule, ACursor);
     Marked := False;
     ShiftState := 0;
end;

procedure TSetItem.SetShiftState( AState: Integer);
begin
     ShiftState := AState;
end;

function TSetItem.GetShiftState: Integer;
begin
     GetShiftState := ShiftState;
end;

procedure TSetItem.Mark;
begin
     Marked := True;
end;

procedure TSetItem.Unmark;
begin
     Marked := False;
end;

function TSetItem.IsMarked: Boolean;
begin
     IsMarked := Marked;
end;


constructor TSet.Create;
begin
     inherited Create;
     Core.Create;
     Items.Create;
     Identifier := 0;
end;

destructor TSet.Destroy;
begin
     Core.Destroy;
     Items.Destroy;
     inherited Destroy;
end;

procedure TSet.AddCoreItem( ACoreItem: PCoreItem);
begin
     if ( ACoreItem <> nil)
     then Core.PushLast( ACoreItem);
end;

procedure TSet.SetID( AIdentifier: Integer);
begin
     Identifier := AIdentifier;
end;

function TSet.GetID: Integer;
begin
     GetID := Identifier;
end;

procedure TSet.MoveItemsToCore( ACoreItems: PCollection);
var TempItem: PCoreItem;
begin
     if ( ACoreItems <> nil)
     then begin
          TempItem := PCoreItem( ACoreItems^.PopFirst);
          while ( TempItem <> nil)
          do begin
             Core.PushLast( TempItem);
             TempItem := PCoreItem( ACoreItems^.PopFirst);
             end;
          end;
end;

procedure TSet.ExpandSet( AGrammar: PGrammar);
var TempCoreItem: PCoreItem;
    TempSetItem: PSetItem;
    LeftSymbol: PParserSymbol;
    TempRule: PRule;

    function FindSame( ARule: PRule): boolean;
    var TempSetItem: PSetItem;
    begin
         if ( ARule <> nil)
         then begin
              TempSetItem := PSetItem( Items.GetFirst);
              while ( TempSetItem <> nil)
              do begin
                 if (( TempSetItem^.GetRule = ARule) and ( TempSetItem^.GetCursor = 1))
                 then begin
                      FindSame := True;
                      exit;
                      end;
                 TempSetItem := PSetItem( Items.GetNext);
                 end;
              end;
         FindSame := False;
    end;

begin
     if ( AGrammar <> nil)
     then begin
          TempCoreItem := PCoreItem( Core.GetFirst);
          while ( TempCoreItem <> nil)
          do begin
             Items.PushLast( New( PSetItem, Create( TempCoreItem^.GetRule, TempCoreItem^.GetCursor)));
             TempCoreItem := PCoreItem( Core.GetNext);
             end;

          TempSetItem := PSetItem( Items.GetFirst);
          while ( TempSetItem <> nil)
          do begin
             LeftSymbol := TempSetItem^.GetCursorSymbol;
             if ( LeftSymbol <> nil)
             then begin
                  TempRule := AGrammar^.GetFirstRule;
                  while ( TempRule <> nil)
                  do begin
                     if (( TempRule^.GetLeftSymbol = LeftSymbol) and not FindSame( TempRule))
                     then Items.PushLast( New( PSetItem, Create( TempRule,1)));
                     TempRule := AGrammar^.GetNextRule;
                     end;
                  end;
             TempSetItem := PSetItem( Items.GetAfter( TempSetItem));
             end;
          end;
end;

function TSet.CreateCoreCollection( ASymbol: PParserSymbol): PContainerCollection;
var
   Collection: PContainerCollection;
   Temp: PSetItem;
begin
     if ( ASymbol <> nil)
     then begin
          Collection := New( PContainerCollection, Create);
          Temp := PSetItem( Items.GetFirst);
          while ( Temp <> nil)
          do begin
             if ( Temp^.GetRule^.GetRightSideSize >= Temp^.GetCursor)
             then if ( Temp^.GetCursorSymbol = ASymbol)
                  then Collection^.PushLast( New( PCoreItem,Create( Temp^.GetRule, Temp^.GetCursor + 1)));
             Temp := PSetItem( Items.GetNext);
             end;
          CreateCoreCollection := Collection;
          end
     else CreateCoreCollection := nil;
end;

function TSet.CompareCoreWith( ACoreItems: PCollection): Boolean;
var TempQuick: PCoreItem;
    TempSlow: PCoreItem;
    Same, NotFoundSame: Boolean;
begin
     if ( ACoreItems <> nil)
     then begin
          if ( ACoreItems^.GetItemsCount = Core.GetItemsCount)
          then begin
               Same := True;
               TempSlow := PCoreItem( ACoreItems^.GetFirst);
               while ( TempSlow <> nil)
               do begin
                  TempQuick := PCoreItem( Core.GetFirst);
                  NotFoundSame := True;
                  while (( TempQuick <> nil) and ( NotFoundSame))
                  do if TempQuick^.SameAs( TempSlow)
                     then NotFoundSame := False
                     else TempQuick := PCoreItem( Core.GetNext);
                  if NotFoundSame
                  then begin
                       TempSlow := nil;
                       Same := False;
                       end
                  else TempSlow := PCoreItem( ACoreItems^.GetNext);
                  end;
               end
          else Same := False;
          CompareCoreWith := Same;
          end
     else CompareCoreWith := False;
end;

function TSet.GetFirstCoreItem: PCoreItem;
begin
     GetFirstCoreItem := PCoreItem( Core.GetFirst);
end;

function TSet.GetNextCoreItem: PCoreItem;
begin
     GetNextCoreItem := PCoreItem( Core.GetNext);
end;

function TSet.GetFirstSetItem: PSetItem;
begin
     GetFirstSetItem := PSetItem( Items.GetFirst);
end;

function TSet.GetNextSetItem: PSetItem;
begin
     GetNextSetItem := PSetItem( Items.GetNext);
end;

function TSet.GetUnmarkedSymbol: PParserSymbol;
var UnmarkedSymbol: PParserSymbol;
    TempSetItem: PSetItem;
begin
     UnmarkedSymbol := nil;
     TempSetItem := PSetItem( Items.GetFirst);
     while ( TempSetItem <> nil)
     do begin
        if (not TempSetItem^.IsMarked)
        then begin
             UnmarkedSymbol := TempSetItem^.GetCursorSymbol;
             if ( UnmarkedSymbol <> nil)
             then break;
             end;
        TempSetItem := PSetItem( Items.GetNext);
        end;
     GetUnmarkedSymbol := UnmarkedSymbol;
end;

procedure TSet.MarkSymbol( ASymbol: PParserSymbol; AShiftState: Integer);
var TempSetItem: PSetItem;
begin
     if (ASymbol <> nil)
     then begin
          TempSetItem := PSetItem( Items.GetFirst);
          while ( TempSetItem <> nil)
          do begin
             if ( TempSetItem^.GetCursorSymbol = ASymbol)
             then begin
                  TempSetItem^.Mark;
                  TempSetItem^.SetShiftState( AShiftState);
                  end;
             TempSetItem := PSetItem( Items.GetNext);
             end;
          end;
end;


constructor TSetCollection.Create;
begin
     inherited Create;
     Sets.Create;
end;

destructor TSetCollection.Destroy;
begin
     Sets.Destroy;
     inherited Destroy;
end;

function TSetCollection.GetSameCoreSet( ACoreItems: PCollection): PSet;
var TempSet: PSet;
begin
     if ( ACoreItems <> nil)
     then begin
          TempSet := PSet( Sets.GetFirst);
          while ( TempSet <> nil)
          do begin
             if TempSet^.CompareCoreWith( ACoreItems)
             then break;
             TempSet := PSet( Sets.GetNext);
             end;
          GetSameCoreSet := TempSet;
          end
     else GetSameCoreSet := nil;
end;

procedure TSetCollection.Build( AGrammar: PGrammar);
var TempSet, AnotherTempSet: PSet;
    TempSymbol: PParserSymbol;
    NewCoreCollection: PContainerCollection;
    TempCoreItem: PCoreItem;
    NewID: Integer;
begin
     TempSet := New( PSet, Create);
     TempSet^.AddCoreItem( New( PCoreItem, Create( AGrammar^.GetFirstRule, 1)));
     TempSet^.SetID( 1);
     Sets.PushLast( TempSet);

     while ( TempSet <> nil)
     do begin
        TempSet^.ExpandSet( AGrammar);
        TempSymbol := TempSet^.GetUnmarkedSymbol;
        while ( TempSymbol <> nil)
        do begin
           NewCoreCollection := TempSet^.CreateCoreCollection( TempSymbol);
           AnotherTempSet := GetSameCoreSet( NewCoreCollection);
           if ( AnotherTempSet <> nil)
           then NewID := AnotherTempSet^.GetID
           else begin
                AnotherTempSet := new( PSet, Create);
                TempCoreItem := PCoreItem( NewCoreCollection^.PopFirst);
                while ( TempCoreItem <> nil)
                do begin
                   AnotherTempSet^.AddCoreItem( TempCoreItem);
                   TempCoreItem := PCoreItem( NewCoreCollection^.PopFirst);
                   end;
                NewID := Sets.GetItemsCount + 1;
                AnotherTempSet^.SetID( NewID);
                Sets.PushLast( AnotherTempSet);
                end;
           TempSet^.MarkSymbol( TempSymbol,NewID);
           TempSymbol := TempSet^.GetUnmarkedSymbol;
           NewCoreCollection^.Free;
           end;
        TempSet := PSet( Sets.GetAfter( TempSet));
        end;
end;

function TSetCollection.GetNumStates: Integer;
begin
     GetNumStates := Sets.GetItemsCount;
end;

function TSetCollection.GetSet( AIndex: Integer): PSet;
begin
     GetSet := PSet( Sets.GetByIndex( AIndex));
end;

{$IFDEF DEBUGSTATE}

procedure TSetCollection.Display;
var TempSet: PSet;
    SetItem: PSetItem;
    TempRule: PRule;
    TempSymbol: PParserSymbol;
    J,I: Word;
begin
     TempSet := PSet( Sets.GetFirst);
     while ( TempSet <> nil)
     do begin
        WriteLn( DebugOutput, '[', TempSet^.GetID, ']');
        SetItem := TempSet^.GetFirstSetItem;
        while ( SetItem <> nil)
        do begin
           TempRule := SetItem^.GetRule;
           if ( TempRule <> nil)
           then begin
                TempSymbol := TempRule^.GetLeftSymbol;
                if TempSymbol <> nil
                then Write( DebugOutput, TempSymbol^.GetTitle, ' -> ')
                else Write( DebugOutput, 'NIL -> ');
                J := TempRule^.GetRightSideSize;
                if (J >= 1)
                then for I := 1 to J
                     do begin
                        if ( SetItem^.GetCursor = I)
                        then Write( DebugOutput,'.');
                        TempSymbol := TempRule^.GetRightSymbol( I);
                        if TempSymbol <> nil
                        then Write( DebugOutput, TempSymbol^.GetTitle, ' ')
                        else Write( DebugOutput, 'NIL ');
                        end;
                if ( SetItem^.GetShiftState <> 0)
                then WriteLn( DebugOutput, '  [', SetItem^.GetShiftState, ']')
                else WriteLn( DebugOutput, 'Reduce');
                end;
           SetItem := TempSet^.GetNextSetItem;
           end;
        WriteLn( DebugOutput);
        TempSet := PSet( Sets.GetNext);
        end;
end;
{$ENDIF}


constructor TReduceManager.Create;
begin
     inherited Create;
     Rules.Create;
end;

destructor TReduceManager.Destroy;
begin
     Rules.Destroy;
     inherited Destroy;
end;

procedure TReduceManager.AppendRule( AReduceRule: PRule);
var TempRule: PRule;
    NewRuleSize: Word;
begin
     if ( AReduceRule <> nil)
     then begin
          NewRuleSize := AReduceRule^.GetRightSideSize;
          TempRule := PRule( Rules.GetFirst);
          while ( TempRule <> nil)
          do if ( TempRule^.GetRightSideSize > NewRuleSize)
             then TempRule := PRule( Rules.GetNext)
             else break;

          if ( TempRule = nil)
          then Rules.PushLast( AReduceRule)
          else Rules.InsertBefore( TempRule, AReduceRule);
          end;
end;


function TReduceManager.GetNumRules: Integer;
begin
     GetNumRules := Rules.GetItemsCount;
end;

function TReduceManager.GetRule( AIndex: Integer): PRule;
begin
     GetRule := PRule( Rules.GetByIndex( AIndex));
end;

function TReduceManager.GetReduceRule( ATranslateStack: PParserStack): PRule;
var TempRule: PRule;
    TempSymbol: PParserSymbol;
    RuleSymbolsCount: Word;
begin
     if ( ATranslateStack <> nil)
     then begin
          TempRule := PRule( Rules.GetFirst);
          while ( TempRule <> nil)
          do begin
             TempSymbol := TempRule^.GetFirstRightSymbol;
             RuleSymbolsCount := TempRule^.GetRightSideSize;
             while (( TempSymbol <> nil) and ( ATranslateStack^.SymbolAtTop( RuleSymbolsCount) = TempSymbol))
             do begin
                TempSymbol := TempRule^.GetNextRightSymbol;
                RuleSymbolsCount := RuleSymbolsCount - 1;
                end;
             if ( RuleSymbolsCount > 0)
             then TempRule := PRule( Rules.GetNext)
             else break;
             end;
          GetReduceRule := TempRule;
          end
     else GetReduceRule := nil;
end;


constructor TParserTable.Create;
begin
     inherited Create;
     Table.SymbolsCount := 0;
     Table.StatesCount := 0;
     Table.ShiftsTable := nil;
     Table.ReduceInfoTable := nil;
end;

destructor TParserTable.Destroy;
var I: Integer;
begin
     FreeTable;
     inherited Destroy;
end;

procedure TParserTable.FreeTable;
var I: Word;
begin
     if (( Table.SymbolsCount > 0) and ( Table.StatesCount > 0))
     then begin
          for I := 1 to Table.SymbolsCount
          do FreeMem( Table.ShiftsTable^[ I], SizeOf( TSymbolCol) * Table.StatesCount);
          FreeMem( Table.ShiftsTable, SizeOf( TTableCols) * Table.SymbolsCount);
          for I := 1 to Table.StatesCount
          do if ( Table.ReduceInfoTable^[ I] <> nil)
             then Table.ReduceInfoTable^[ I]^.Free;
          FreeMem( Table.ReduceInfoTable, SizeOf( PReduceManager) * Table.StatesCount);
          end;
     Table.SymbolsCount := 0;
     Table.StatesCount := 0;
     Table.ShiftsTable := nil;
     Table.ReduceInfoTable := nil;
end;

procedure TParserTable.AllocateTable( ASymbolsCount, AStatesCount: Word);
var I: Word;
begin
     FreeTable;
     if (( ASymbolsCount > 0) and ( AStatesCount > 0))
     then begin
          Table.SymbolsCount := ASymbolsCount;
          Table.StatesCount := AStatesCount;
          GetMem( Table.ShiftsTable, SizeOf( TTableCols) * Table.SymbolsCount);
          for I := 1 to Table.SymbolsCount
          do begin
             GetMem( Table.ShiftsTable^[I], SizeOf( TSymbolCol) * Table.StatesCount);
             FillChar( Table.ShiftsTable^[I]^, SizeOf( TSymbolCol) * Table.StatesCount, #0);
             end;
          GetMem( Table.ReduceInfoTable, SizeOf( PReduceManager) * Table.StatesCount);
          for I := 1 to Table.StatesCount
          do Table.ReduceInfoTable^[I] := nil;
          end;
end;

procedure TParserTable.BuildTableFromCollection( ASetCollection: PSetCollection; ASymbolsCount: Word);
var StatesCount: Word;
    StateNo: Word;
    TempSet: PSet;
    TempSetItem: PSetItem;
    CursorSymbol: PParserSymbol;
    ShiftState: Word;
    SymbolId: Word;
begin
     if (( ASetCollection <> nil) and (ASymbolsCount > 0))
     then begin
          StatesCount := ASetCollection^.GetNumStates;
          if ( StatesCount > 0)
          then begin
               AllocateTable( ASymbolsCount, StatesCount);
               for StateNo := 1 to StatesCount
               do begin
                  TempSet := ASetCollection^.GetSet( StateNo);
                  if ( TempSet <> nil)
                  then begin
                       TempSetItem := TempSet^.GetFirstSetItem;
                       while ( TempSetItem <> nil)
                       do begin
                          CursorSymbol := TempSetItem^.GetCursorSymbol;
                          ShiftState := TempSetItem^.GetShiftState;
                          if (( ShiftState > 0) and ( ShiftState <= StatesCount) and ( CursorSymbol <> nil))
                          then begin
                               SymbolId := CursorSymbol^.GetID;
                               if (( SymbolId > 0) and ( SymbolId <= ASymbolsCount))
                               then Table.ShiftsTable^[ SymbolId]^[ StateNo] := ShiftState;
                               end
                          else begin
                               if (( ShiftState = 0) and ( CursorSymbol = nil))
                               then begin
                                    if ( Table.ReduceInfoTable^[ StateNo] = nil)
                                    then Table.ReduceInfoTable^[ StateNo] := New( PReduceManager, Create);
                                    Table.ReduceInfoTable^[ StateNo]^.AppendRule( TempSetItem^.GetRule);
                                    end;
                               end;
                          TempSetItem := TempSet^.GetNextSetItem;
                          end;
                       end;
                  end;
               end
          else FreeTable;
          end
     else FreeTable;
end;

function TParserTable.Build( AGrammar: PGrammar; ASymbolsCount: Word): Boolean;
var SetCollection: PSetCollection;
begin
     if ( AGrammar <> nil)
     then begin
          SetCollection := New( PSetCollection, Create);
          SetCollection^.Build( AGrammar);
{$IFDEF DEBUGSTATE}
          SetCollection^.Display;
{$ENDIF}
          BuildTableFromCollection( SetCollection, ASymbolsCount);
          SetCollection^.Free;
          Build := True;
          end
     else begin
          FreeTable;
          Build := False;
          end;
end;

function TParserTable.IsTableExist: Boolean;
begin
     IsTableExist := (( Table.ShiftsTable <> nil) and
                      ( Table.ReduceInfoTable <> nil) and
                      ( Table.SymbolsCount > 0) and
                      ( Table.StatesCount > 0));
end;

function TParserTable.GetStatesCount: Word;
begin
     GetStatesCount := Table.StatesCount;
end;

function TParserTable.GetSymbolsCount: Word;
begin
     GetSymbolsCount := Table.SymbolsCount;
end;

function TParserTable.GetNextState( AState: Word; ASymbolId: Word): Word;
begin
     if (( AState > 0) and ( AState <= Table.StatesCount) and (ASymbolId > 0) and (ASymbolId <= Table.SymbolsCount))
     then begin
          GetNextState := Table.ShiftsTable^[ ASymbolId]^[ AState];
          end
     else GetNextState := 0;
end;


function TParserTable.AnyReduceAtState( AState: Word): Boolean;
begin
     if (( AState > 0) and ( AState <= Table.StatesCount))
     then AnyReduceAtState := ( Table.ReduceInfoTable^[ AState] <> nil)
     else AnyReduceAtState := False;
end;

function TParserTable.GetReduceInfo( AState: Word): PReduceManager;
begin
     if (( AState > 0) and ( AState <= Table.StatesCount))
     then GetReduceInfo := Table.ReduceInfoTable^[ AState]
     else GetReduceInfo := nil;
end;


constructor TStackItem.Create( AState: Word; ASymbol: PParserSymbol; AAttribute: PGeneric);
begin
     inherited Create;
     State := AState;
     Symbol := ASymbol;
     Attribute := AAttribute;
end;

destructor TStackItem.Destroy;
begin
     if ( Attribute <> nil)
     then Attribute^.Free;
     inherited Destroy;
end;

function TStackItem.GetState: Word;
begin
     GetState := State;
end;

function TStackItem.GetSymbol: PParserSymbol;
begin
     GetSymbol := Symbol;
end;

function TStackItem.GetAttribute: PGeneric;
begin
     GetAttribute := Attribute;
end;

function TStackItem.ReleaseAttribute: PGeneric;
begin
     ReleaseAttribute := Attribute;
     Attribute := nil;
end;


constructor TParserStack.Create;
begin
     inherited Create;
     Items.Create;
end;

destructor TParserStack.Destroy;
begin
     Items.Destroy;
     inherited Destroy;
end;

procedure TParserStack.Clear;
begin
     Items.Clear;
end;

function TParserStack.Push( AState: Word; ASymbol: PParserSymbol; AAttribute: PGeneric): Boolean;
var NewStackItem: PStackItem;
begin
     NewStackItem := New( PStackItem, Create( AState, ASymbol, AAttribute));
     Items.PushFirst( NewStackItem);
     Push := True;
end;

function TParserStack.Pop( var AState: Word; var ASymbol: PParserSymbol; var AAttribute: PGeneric): Boolean;
var PopedItem: PStackItem;
begin
     PopedItem := PStackItem( Items.Popfirst);
     if ( PopedItem <> nil)
     then begin
          AState := PopedItem^.GetState;
          ASymbol := PopedItem^.GetSymbol;
          AAttribute := PopedItem^.ReleaseAttribute;
          PopedItem^.Free;
          Pop := True;
          end
     else begin
          AState := 0;
          Pop := False;
          end;
end;

function TParserStack.SymbolAtTop( ADistance: Word): PParserSymbol;
var TempStacItem: PStackItem;
begin
     TempStacItem := PStackItem( Items.GetByIndex( ADistance));
     if ( TempStacItem <> nil)
     then SymbolAtTop := TempStacItem^.GetSymbol
     else SymbolAtTop := nil;
end;

function TParserStack.TopState: Word;
var TempStacItem: PStackItem;
begin
     TempStacItem := PStackItem( Items.GetFirst);
     if ( TempStacItem <> nil)
     then TopState := TempStacItem^.GetState
     else TopState := 0;
end;

function TParserStack.Size: Word;
begin
     Size := Items.GetItemsCount;
end;

{$IFDEF DEBUGSTATE}
procedure TParserStack.Display;
var TempStacItem: PStackItem;
begin
     TempStacItem := PStackItem( Items.GetLast);
     while ( TempStacItem <> nil)
     do begin
        Write( DebugOutput, '[', TempStacItem^.GetState, ']');
        if ( TempStacItem^.GetSymbol <> nil)
        then Write( DebugOutput, TempStacItem^.GetSymbol^.GetTitle)
        else Write(DebugOutput, 'NULL');
        TempStacItem := PStackItem( Items.GetPrev);
        end;
     WriteLn( DebugOutput);
end;
{$ENDIF}


constructor TParser.Create( AOwner: PErrGeneric; ASymbols: PCollection; AGrammar: PGrammar);
begin
     inherited Create( AOwner);
     Symbols := ASymbols;
     Grammar := AGrammar;
     Table.Create;
     Stack.Create;
     ReducedSymbolsAttributes.Create;
end;

destructor TParser.Destroy;
begin
     Stack.Destroy;
     Table.Destroy;
     ReducedSymbolsAttributes.Destroy;
     inherited Destroy;
end;

function TParser.BuildParser: Boolean;
begin
     if ( Grammar <> nil) and ( Symbols <> nil)
     then BuildParser := Table.Build( Grammar, Symbols^.GetItemsCount)
     else BuildParser := False;
{$IFDEF DEBUGSTATE}
     DesplayParserTable;
{$ENDIF}
end;

procedure TParser.GenerateOutput( ARule: PRule; AAttributes: PCollection);
begin
     { Abstract method ... }
end;

procedure TParser.ReduceByRule( ARule: PRule);
var PopedSymbolsCount: Word;
    TempTopSymbol: PParserSymbol;
    NewTopSymbol: PParserSymbol;
    NewTopState: Word;
    TempTopState: Word;
    TempTopAttribute: PGeneric;
begin
     if ( ARule <> nil)
     then begin
          ReducedSymbolsAttributes.Clear;
          NewTopSymbol := ARule^.GetLeftSymbol;
          PopedSymbolsCount := ARule^.GetRightSideSize;
          while (PopedSymbolsCount > 0)
          do begin
             Stack.Pop( TempTopState, TempTopSymbol, TempTopAttribute);
             if ( TempTopAttribute <> nil)
             then ReducedSymbolsAttributes.PushFirst( TempTopAttribute);
             PopedSymbolsCount := PopedSymbolsCount - 1;
             end;
          if ( NewTopSymbol <> nil)
          then begin
               TempTopState := Table.GetNextState( Stack.TopState, NewTopSymbol^.GetID);
               Stack.Push( TempTopState, NewTopSymbol, nil);
               end;
          GenerateOutput( ARule, @ReducedSymbolsAttributes);
          end;
end;

function TParser.InitTranslation: Boolean;
begin
     if Table.IsTableExist
     then begin
          Stack.Clear;
          Stack.Push( 1, nil, nil);
          InitTranslation := True;
          end
     else InitTranslation := False;
end;

function TParser.DoneTranslation: Boolean;
begin
     if ( Stack.TopState <> 1)
     then DoneTranslation := False
     else DoneTranslation := True;
     Stack.Clear;
end;

function TParser.TakeNextSymbol( ASymbol: PParserSymbol; ASymbolAttr: PGeneric): Boolean;
var
   NextState: Word;
   ReduceManager: PReduceManager;
   ReduceRule: PRule;
   SymbolNotAccepted: Boolean;
begin
     if ( ASymbol <> nil)
     then begin
          NextState := Table.GetNextState( Stack.TopState, ASymbol^.GetID);
          if ( NextState <> 0)
          then Stack.Push( NextState, ASymbol, ASymbolAttr)
          else begin
               SymbolNotAccepted := True;
               ReduceManager := Table.GetReduceInfo( Stack.TopState);
               while ( ReduceManager <> nil)
               do begin
                  ReduceRule := ReduceManager^.GetReduceRule( @Stack);
                  if ( ReduceRule <> nil)
                  then begin
                       ReduceByRule( ReduceRule);
                       NextState := Table.GetNextState( Stack.TopState, ASymbol^.GetID);
                       if ( NextState <> 0)
                       then begin
                            Stack.Push( NextState, ASymbol, ASymbolAttr);
                            SymbolNotAccepted := False;
                            break;
                            end
                       else ReduceManager := Table.GetReduceInfo( Stack.TopState);
                       end
                  else break;
                  end;
               if SymbolNotAccepted
               then begin
                    if ( ASymbolAttr <> nil)
                    then ASymbolAttr^.Free;
                    AddError( New( PMessageError, Create( 'PARSER ERROR: Unexpected symbol.')));
                    TakeNextSymbol := False;
                    Exit;
                    end;
               end;
          end
     else begin
          ReduceManager := Table.GetReduceInfo( Stack.TopState);
          while ( ReduceManager <> nil)
          do begin
             ReduceRule := ReduceManager^.GetReduceRule( @Stack);
             if ( ReduceRule <> nil)
             then begin
                  ReduceByRule( ReduceRule);
                  ReduceManager := Table.GetReduceInfo( Stack.TopState);
                  end
             else begin
                  AddError( New( PMessageError, Create( 'PARSER ERROR: Rule not found to reduuce.')));
                  TakeNextSymbol := False;
                  Exit
                  end;
             end;
          if ( Stack.TopState <> 1)
          then begin
               AddError( New( PMessageError, Create( 'PARSER ERROR: Statment body not complete.')));
               TakeNextSymbol := False;
               Exit
               end;
          end;
     TakeNextSymbol := True;
end;

{$IFDEF DEBUGSTATE}
procedure TParser.DesplayParserTable;
var Symbol: Integer;
    State: Integer;
    I,J,K: Integer;
    DelayTime: Integer;
    Key: Char;
    TempSymbol: PParserSymbol;
    TempRule: PRule;
begin
     if Table.IsTableExist
     then begin
          DelayTime := 100;
          WriteLn( DebugOutput);
          Write( DebugOutput, '  ');
          for Symbol := 1 to Table.GetSymbolsCount
          do Write( DebugOutput, Symbol:3);

          for State := 1 to Table.GetStatesCount
          do begin
             WriteLn( DebugOutput);
             Write( DebugOutput, State:2);
             Write( DebugOutput, '.');
             for Symbol := 1 to Table.GetSymbolsCount
             do begin
                if ( Table.GetNextState( State, Symbol) <> 0)
                then Write( DebugOutput, Table.GetNextState( State, Symbol):2, ' ')
                else Write( DebugOutput, 'ER ');
                end;

             if Table.AnyReduceAtState( State)
             then begin
                  for K:= 1 to Table.GetReduceInfo( State)^.GetNumRules
                  do begin
                     WriteLn( DebugOutput);
                     Write( DebugOutput, '        ');
                     Write( DebugOutput, '[ ');
                     TempRule := Table.GetReduceInfo( State)^.GetRule( K);
                     if ( TempRule <> nil)
                     then begin
                          TempSymbol := TempRule^.GetLeftSymbol;
                          if TempSymbol <> nil
                          then Write( DebugOutput, TempSymbol^.GetTitle, ' <- ')
                          else Write( DebugOutput, 'NIL <-');
                          J := TempRule^.GetRightSideSize;
                          if (J >= 1)
                          then for I := 1 to J
                               do begin
                                  TempSymbol := TempRule^.GetRightSymbol( I);
                                  if TempSymbol <> nil
                                  then Write( DebugOutput, TempSymbol^.GetTitle, ' ')
                                  else Write( DebugOutput, 'NIL ');
                                  end;
                          Write( DebugOutput, ' ]');
                          end;
                     end;
                  end;

             end;
             WriteLn( DebugOutput);
          end
     else WriteLn( DebugOutput, 'No table ...');
end;
{$ENDIF}

end.