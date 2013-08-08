{*************************************************}
{*                                               *}
{*   Expresion unit                              *}
{*                                               *}
{*************************************************}

unit Expresion;

interface

uses Generics, Lexical;

type
    PValueInfo = ^TValueInfo;
    TValueInfo = object( TGeneric)
    public
       constructor Create;
       destructor Destroy; virtual;
       function GetValue: Longint; virtual;
       procedure SetValue( AValue: Longint); virtual;
       end;

    PExpresion = ^TExpresion;
    TExpresion = object( TErrGeneric)
    private
       PreFix: TContainerCollection;
    public
       constructor Create( AOwner: PErrGeneric);
       destructor Destroy; virtual;
       function GetVariableInfo( AVarStr: string): PValueInfo; virtual;
       function GetParameterValue( AParamID: Word; AParamAttrib: string): Longint;virtual;
       function Build(AExpresion: string): Boolean;
       function Evaluate: Longint;
       end;

implementation

type
    TSymbol = ( symNone, symOperation, symConst, symVar, symParam, symLeftArc, symRightArc);

    TSymbolInfo = record
       case Symbol: TSymbol of
       symNone,
       symLeftArc,
       symRightArc: ();
       symOperation: ( Operation: TOperation);
       symConst: ( Value: Longint);
       symVar: ( Info: PValueInfo);
       symParam: ( Id: Word; ParamAttr: string[64]);
       end;

    PStackItem = ^TStackItem;
    TStackItem = object( TGeneric)
    private
       SymbolInfo: TSymbolInfo;
    public
       constructor CreateLeftArc;
       constructor CreateRightArc;
       constructor CreateOperation( AOperation: TOperation);
       constructor CreateConstant( AValue: Longint);
       constructor CreateVariable( AInfo: PValueInfo);
       constructor CreateParam( AId: Word; AParamAttr: string);
       destructor Destroy; virtual;
       function GetSymbol: TSymbol;
       function GetOperation: TOperation;
       function GetConstantValue: Longint;
       function GetVariableInfo: PValueInfo;
       function GetParamId: Word;
       function GetParamAttr: string;
       end;


constructor TValueInfo.Create;
begin
     inherited Create;
end;

destructor TValueInfo.Destroy;
begin
     inherited Destroy;
end;

function TValueInfo.GetValue: Longint;
begin
     GetValue := 0;
end;

procedure TValueInfo.SetValue( AValue: Longint);
begin
end;


constructor TStackItem.CreateLeftArc;
begin
     inherited Create;
     SymbolInfo.Symbol := symLeftArc;
end;

constructor TStackItem.CreateRightArc;
begin
     inherited Create;
     SymbolInfo.Symbol := symRightArc;
end;

constructor TStackItem.CreateOperation( AOperation: TOperation);
begin
     inherited Create;
     SymbolInfo.Symbol := symOperation;
     SymbolInfo.Operation := AOperation;
end;

constructor TStackItem.CreateConstant( AValue: Longint);
begin
     inherited Create;
     SymbolInfo.Symbol := symConst;
     SymbolInfo.Value := AValue;
end;

destructor TStackItem.Destroy;
begin
     inherited Destroy;
end;

constructor TStackItem.CreateVariable( AInfo: PValueInfo);
begin
     inherited Create;
     SymbolInfo.Symbol := symVar;
     SymbolInfo.Info := AInfo;
end;

constructor TStackItem.CreateParam( AId: Word; AParamAttr: string);
begin
     inherited Create;
     SymbolInfo.Symbol := symParam;
     SymbolInfo.Id := AId;
     SymbolInfo.ParamAttr := AParamAttr;
end;


function TStackItem.GetSymbol: TSymbol;
begin
     GetSymbol := SymbolInfo.Symbol;
end;

function TStackItem.GetOperation: TOperation;
begin
     GetOperation := SymbolInfo.Operation;
end;


function TStackItem.GetConstantValue: Longint;
begin
     GetConstantValue := SymbolInfo.Value;
end;


function TStackItem.GetVariableInfo: PValueInfo;
begin
     GetVariableInfo := SymbolInfo.Info;
end;


function TStackItem.GetParamId: Word;
begin
     GetParamId := SymbolInfo.Id;
end;

function TStackItem.GetParamAttr: string;
begin
     GetParamAttr := SymbolInfo.ParamAttr;
end;


constructor TExpresion.Create( AOwner: PErrGeneric);
begin
     inherited Create( AOwner);
     PreFix.Create;
end;

destructor TExpresion.Destroy;
begin
     PreFix.Destroy;
     inherited Destroy;
end;

function TExpresion.GetVariableInfo( AVarStr: string): PValueInfo;
begin
     GetVariableInfo := nil;
end;

function TExpresion.GetParameterValue( AParamID: Word; AParamAttrib: string): Longint;
begin
     GetParameterValue := AParamID;
end;

function TExpresion.Build( AExpresion: string): Boolean;
var Stack: TContainerCollection;
    Expresion: TStringSource;
    Lexican: TLexican;
    LexicanAttr: TLexicanAttribute;
    ValueInfo: PValueInfo;
    StackItem: PStackItem;
    OpForce: Integer;
    TempOperation: TOperation;
    Found: Boolean;
    TempStr: string;

    function GetOperationForce( Operation: TOperation): Integer;
    begin
         case Operation of
         opPluss,
         opMinus: GetOperationForce := 1;
         opMul,
         opDiv,
         opMod: GetOperationForce := 2;
         opPower: GetOperationForce := 3;
         opSignalNeg,
         opSignalPos: GetOperationForce := 4;
         else
             GetOperationForce := 0;
         end;
    end;

begin
     Build := True;
     Stack.Create;
     PreFix.Clear;
     Expresion.Create( AExpresion);
     Expresion.Reset;
     Lexican := Expresion.NextLexican;
     repeat
           case Lexican of
           lexIdentifier: begin
                          TempStr := Expresion.LexicanString;
                          Lexican := Expresion.NextLexican;
                          if Lexican <> lexDPoint
                          then begin
                               ValueInfo := GetVariableInfo( TempStr);
                               if ( ValueInfo <> nil)
                               then begin
                                    StackItem := New( PStackItem,CreateVariable( ValueInfo));
                                    Stack.PushFirst( StackItem);
                                    end
                               else begin
                                    Build := False;

                                    Break;
                                    end;
                               end
                          else begin
                               if Expresion.NextLexican = lexInteger
                               then begin
                                    Expresion.GetLexicanAttribute( LexicanAttr);
                                    StackItem := New( PStackItem, CreateParam( LexicanAttr.IntegerValue, TempStr));
                                    Stack.PushFirst( StackItem);
                                    end
                               else begin
                                    Build := False;
                                    AddError( New( PMessageError,Create( 'EXPRESION ERROR: Integer expected.')));
                                    Break;
                                    end;
                               Lexican := Expresion.NextLexican;
                               end;
                          end;
           lexInteger: begin
                       Expresion.GetLexicanAttribute( LexicanAttr);
                       StackItem := New( PStackItem, CreateConstant( LexicanAttr.IntegerValue));
                       Stack.PushFirst( StackItem);
                       Lexican := Expresion.NextLexican;
                       end;
           lexOperation: begin
                         Expresion.GetLexicanAttribute( LexicanAttr);
                         OpForce := GetOperationForce( LexicanAttr.Operation);
                         StackItem := PStackItem( Stack.PopFirst);
                         while ( StackItem <> nil)
                         do begin
                            if ( StackItem^.GetSymbol = symOperation)
                            then begin
                                 if ( GetOperationForce( StackItem^.GetOperation) >= OpForce)
                                 then begin
                                      PreFix.PushFirst( StackItem);
                                      StackItem := PStackItem( Stack.PopFirst);
                                      end
                                 else begin
                                      Stack.PushFirst( StackItem);
                                      StackItem := nil;
                                      end;
                                 end
                            else begin
                                 if ( StackItem^.GetSymbol <> symLeftArc)
                                 then begin
                                      PreFix.PushFirst( StackItem);
                                      StackItem := PStackItem( Stack.PopFirst);
                                      end
                                 else begin
                                      Stack.PushFirst( StackItem);
                                      StackItem := nil;
                                      end;
                                 end;
                            end;
                         StackItem := New( PStackItem, CreateOperation( LexicanAttr.Operation));
                         Stack.PushFirst( StackItem);
                         Lexican := Expresion.NextLexican;
                         end;
           lexArcLeft: begin
                       StackItem := New( PStackItem, CreateLeftArc);
                       Stack.PushFirst( StackItem);
                       Lexican := Expresion.NextLexican;
                       end;
           lexArcRight: begin
                        StackItem := PStackItem( Stack.PopFirst);
                        Found := False;
                        while ( StackItem <> nil)
                        do begin
                           if ( StackItem^.GetSymbol <> symLeftArc)
                           then begin
                                PreFix.PushFirst( StackItem);
                                StackItem := PStackItem( Stack.PopFirst);
                                end
                           else begin
                                StackItem^.Free;
                                StackItem := nil;
                                Found := True;
                                end;
                           end;
                        if not Found
                        then begin
                             Build := False;
                             AddError( New( PMessageError, Create( 'EXPRESION ERROR: Not expected arc.')));
                             Break;
                             end;
                        Lexican := Expresion.NextLexican;
                        end;
           lexNone: begin
                    end;
           else
               Build := False;
               AddError( New( PMessageError, Create( 'EXPRESION ERROR: Bad symbol.')));
               Break;
           end
     until ( Lexican = lexNone) or ( Lexican = lexError);
     StackItem := PStackItem( Stack.PopFirst);
     while ( StackItem <> nil)
     do begin
        if ( StackItem^.GetSymbol <> symLeftArc)
        then begin
             PreFix.PushFirst( StackItem);
             StackItem := PStackItem( Stack.PopFirst);
             end
        else begin
             StackItem^.Free;
             StackItem := nil;
             Build := False;
             AddError( New( PMessageError, Create( 'EXPRESION ERROR: Expresion not complete.')));
             end;
        end;

     Expresion.Destroy;
     Stack.Destroy;
end;

function TExpresion.Evaluate: Longint;
var First: Boolean;

    function EvaluateTerm: Longint;
    var StackItem: PStackItem;
        T1,T2: Longint;
    begin
         if not First
         then StackItem := PStackItem( PreFix.GetNext)
         else begin
              StackItem := PStackItem( PreFix.GetFirst);
              First := False;
              end;
         if ( StackItem <> nil)
         then begin
              case StackItem^.GetSymbol of
              symOperation: begin
                            case StackItem^.GetOperation of
                            opPluss: begin
                                     T1 := EvaluateTerm;
                                     T2 := EvaluateTerm;
                                     EvaluateTerm := T1 + T2;
                                     end;
                            opMinus: begin
                                     T1 := EvaluateTerm;
                                     T2 := EvaluateTerm;
                                     EvaluateTerm := T2 - T1;
                                     end;
                            opMul: begin
                                   T1 := EvaluateTerm;
                                   T2 := EvaluateTerm;
                                   EvaluateTerm := T1 * T2;
                                   end;
                            opDiv: begin
                                   T1 := EvaluateTerm;
                                   T2 := EvaluateTerm;
                                   EvaluateTerm := T1 div T2;
                                   end;
                            opMod: begin
                                   T1 := EvaluateTerm;
                                   T2 := EvaluateTerm;
                                   EvaluateTerm := T1 mod T2;
                                   end;
                            opPower: begin
                                     T1 := EvaluateTerm;
                                     T2 := EvaluateTerm;
                                     EvaluateTerm := T1 * T2;
                                     end;
                            opSignalPos: EvaluateTerm := EvaluateTerm;
                            opSignalNeg: EvaluateTerm := - EvaluateTerm;
                            end;
                            end;
              symParam: EvaluateTerm := GetParameterValue( StackItem^.GetParamId, StackItem^.GetParamAttr);
              symVar: if ( StackItem^.GetVariableInfo <> nil)
                      then EvaluateTerm := StackItem^.GetVariableInfo^.GetValue
                      else EvaluateTerm := 0;
              symConst: EvaluateTerm := StackItem^.GetConstantValue;
              end;
              end
         else begin
              AddError( New( PMessageError,Create( 'EXPRESION ERROR: Expresion evalation error.')));
              EvaluateTerm := 0;
              end;
    end;
begin
     First := True;
     Evaluate := EvaluateTerm;
end;

end.