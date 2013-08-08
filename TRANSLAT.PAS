{*************************************************}
{*                                               *}
{*   Translator program                          *}
{*                                               *}
{*   This program is object code generator       *}
{*   it translate from intermidate code          *}
{*   to assembly language program.               *}
{*                                               *}
{*   Written by Rsslan Kefri, 1997               *}
{*                                               *}
{*   Syria - Hama - Tel (033-237297)             *}
{*                                               *}
{*************************************************}

program Translator;

uses Objects, Generics, Lexical, SymbolsTable, Parser, Expresion, Strings, Dos;

const
     TYPEDEF_CMD        = '#typedef';{ used in define file, to define new type symbol }
     OPDEF_CMD          = '#opdef';{ used in define file, to define new operation symbol }
     SYMDEF_CMD         = '#symdef';{ used in define file, to define new extra symbol }

     MACRODEF_CMD       = '#macro';{ used in define file, to define new macro symbol }
     MAPDEF_CMD         = '#map';{ used in define file, to define maps of code }
     GLOBDEF_CMD        = '#global';{ used in translated file, to define global variable }
     PROCDEF_CMD        = '#proc';{ used in translated file, to start defination of procedure }
     PARAMDEF_CMD       = '#param';{ used in translated file, to define parameters in a procedure defination section }
     LOCALDEF_CMD       = '#local';{ used in translated file, to define locals in a procedure defination section }
     RETURNDEF_CMD      = '#return';{ used in translated file, to define return value type }
     BLOCKSTART_CMD     = '#begin';{ used in translated file, to identify the parser block start }
     BLOCKEND_CMD       = '#end';{ used in translated file, to identify the parser block end }
     PARAMPASS_CMD      = '#param';{ used in translated file, to start the call operation define }
     CALL_CMD           = '#call';{ used in translated file, to finish the call operation define }
     FREERESULT_CMD     = '#freereturn';{ used in translated file, to free last returned result from stack }

     GLOBAL_SYM         = 'glob';{ used in both files, to identify symbol is a glbal variable of type X }
     LOCAL_SYM          = 'loc';{ used in both files, to identify symbol is a local variable of type X }
     PARAMETER_SYM      = 'par';{ used in both files, to identify symbol is a parameter variable of type X }
     CONSTANT_SYM       = 'con';{ used in both files, to identify symbol is a constant of type X }
     OPERATION_SYM      = 'op';{ used in both files, to identify symbol is an operation X }
     ID_SYM             = 'id';{ used in both files, to identify symbol is a number }

     GLOBALMAP_SYM      = 'global';{ used in define file, to define map of all generated program }
     PROCEDUREMAP_SYM   = 'proc';{ used in define file, to define map of generated procedure code }
     CALLMAP_SYM        = 'call';{ used in define file, to define map of procedure call operation code }
     MAINMAP_SYM        = 'main';{ used in define file, to define map of main part of program }

     PARAMETERINITMACRO_SYM     = 'parinit';{ used in define file, to define macro that init a parameter of a type X witch may
be constant, global ... }
     SUBEXPRESIONMACRO_SYM      = 'subexp';{ used in define file, to define macro that calculate sub expresion }
     BLOCKMACRO_SYM             = 'block';{ used in define file, to define extra macro that can be used in map defines }
     FREERESULTMACRO_SYM        = 'freereturn';{ used in define file, to define macro that free return result of function from
stack }

     PARAMETERSINIT_SYM         = 'paramsinit';{ used in define file, to represent the code of init a parameters }
     CODE_SYM                   = 'code';{ used in define file, to represent the code procedure or all program }

     OFFSET_ATTR                = 'OFFSET';{ used in translated file, to retrive offset attribute of symbol }
     BACKOFFSET_ATTR            = 'BACKOFFSET';{ used in translated file, to retrive back offset attribute of symbol }
     SIZE_ATTR                  = 'SIZE';{ used in translated file, to retrive size attribute of symbol }
     VALUE_ATTR                 = 'VALUE';{ used in translated file, to retrive value attribute of symbol }
     ID_ATTR                    = 'ID';{ used in translated file, to retrive id integer attribute of symbol }

     STATMENT_SYM               = 'STATMENT';
type
    PLongint = ^Longint;

    { symbols type in symbols table }
    TSymbolType = ( stNone,
                    stVariable,   { the symbol is a trnslation time variable used in macros parameters calculations }
                    stOperation,  { the symbol is defined as operation }
                    stType,       { the symbol is defined as a type name }
                    stExtraSymbol,{ the symbol is defined as auxliary symbol used to define sub expresions rules }
                    stBlock);     { the symbol is defined as macro block used in map defines }

    TCallParam = ( cpConst,   { passed parameter is a constant value }
                   cpGlobal,  { passed parameter is a global variable value }
                   cpLocal,   { passed parameter is a local variable value of current procedure }
                   cpParam); { passed parameter is a parameter value of current procedure }

    PMacroParameter = ^TMacroParameter;
    TMacroParameter = object( TExpresion)
    private
        Position: Word;      { offset of parameter position in macro block }
        ExtraInfo: Pointer;  { temp pointer to spcial data and objects }

        function GetVariableInfo( AVarStr: string): PValueInfo; virtual; { gets the translation time variable object }
        function GetParameterValue( AParamID: Word; AParamAttrib: string): Longint;virtual;{ gets the rule symbol attribute val
ue, used during reduce rule and calculation of rule macro parameters . . . }
    public
        constructor Create( AOwner: PErrGeneric; APosition: Word);
        destructor Destroy; virtual;
        function ParseExpresion( AExpresion: string; ASymbolsTable: PSymbolsTable): Boolean;{ analyse the expresion string and
create the prefix nation expresion stared as collection of term, this to speed up prameters calculations }
        function GetPosition: Word;{ retrive the position of this parameter in macro body }
        function GetOutput(AParameters: PCollection): string;{ calculate the value and generate output string of this parameter
 }
        end;

    PMacro = ^TMacro;
    TMacro = object( TErrGeneric)
    private
        MacroBody: PChar;{ pointer to block of chars that represent the macro body }
        MacroBodySize: Word;{ macro body chars count }
        Parameters: TContainerCollection;{ collection of ~TMacroParameter~ objects that represent macro parameters }
    public
        constructor Create( AOwner: PErrGeneric);
        destructor Destroy; virtual;
        function Build( ASymbolsTable: PSymbolsTable; ABody: PChar; ASize: Word): Boolean;{ analyse the input macro body chars
to retrive the parameters of macro, and parse it to create ~TMacroParameter~ objects and strore them in ~Parameters~ collection
 for use in macro output generation }
{$IFDEF DEBUGSTATE}
        procedure Display;
{$ENDIF}
        procedure GenerateOutput( AOutputStream: PStream;
                                  AAttributes: PCollection);{ output the macro to stream, the ~AAttributes~ is a collection of
reduced rule symbols attributes, this parameter used if this macro is a rule reduce output }
        end;

    TMapItemType = ( miMacro,       { macro item is a macro block }
                     miCode,        { macro item is a code of program or procedure }
                     miParamsInit); { macro item is a code of initialising of passed parameters in call operation }

    PMapItem = ^TMapItem;
    TMapItem = object( TGeneric)
    private
       ItemType: TMapItemType; { defines the map item type }
       Macro: PMacro; { (Macro <> nil) if (ItemType = miMacro), points to macro that must be emited as this map item }
    public
       constructor Create( AItemType: TMapItemType; AMacro: PMacro);
       function GetItemType: TMapItemType; { retrives the map item type }
       function GetMacro: PMacro; { retrives the macro object }
       end;

    PMap = ^TMap;
    TMap = object( TGeneric)
    private
       Items: TContainerCollection; { collection of ~TMapItem~ items }
    public
       constructor Create;
       destructor Destroy;virtual;
       procedure Append( AItem: PMapItem);
       function GetFirst: PMapItem;
       function GetNext: PMapItem;
       end;


    { symbol table entry attributes abstract object }
    PSymbolAttributes = ^TSymbolAttributes;
    TSymbolAttributes = object( TGeneric)
    public
       function GetSymbolType: TSymbolType; virtual; { returns ~stNone~ }
       end;

    { symbol table entry attributes for translate time variable }
    PVariableRecord = ^TVariableRecord;
    TVariableRecord = object( TSymbolAttributes)
    private
       ValueInfo: PValueInfo; { variable info objcet }
    public
       constructor Create( AValueInfo: PValueInfo);
       destructor Destroy; virtual;
       function GetSymbolType: TSymbolType; virtual; { returns ~stVariable~ }
       function GetValueInfo: PValueInfo;{ used to retrive variable info object }
       end;

    { symbol table entry attributes for operation name }
    POperationRecord = ^TOperationRecord;
    TOperationRecord = object( TSymbolAttributes)
    private
       OperationSymbol: PParserSymbol;
    public
       constructor Create( ASymbol: PParserSymbol);
       function GetSymbolType: TSymbolType; virtual; { returns ~stOperation~ }
       function GetSymbol: PParserSymbol; { returns the parser symbol object }
       end;

    { symbol table entry attributes for type name }
    PTypeRecord = ^TTypeRecord;
    TTypeRecord = object( TSymbolAttributes)
    private
        TypeSize: Longint;                  { size of this type in defined processor esential words }

        ConstantSymbol: PParserSymbol;      { parser symbol object of this type constant }
        VariableSymbol: PParserSymbol;      { parser symbol object of this type variable }
        LocalSymbol: PParserSymbol;         { parser symbol object of this type local variable }
        ParameterSymbol: PParserSymbol;     { parser symbol object of this type parameter }

        VariableParameterInitMacro: PMacro; { macro used to pass variable value of this type as parameters to called procedure}
        ConstantParameterInitMacro: PMacro; { macro used to pass constant value of this type as parameters to called procedure}
        LocalParameterInitMacro: PMacro;    { macro used to pass local variable value of this type as parameters to called pro
cedure }
        ParameterParameterInitMacro: PMacro;{ macro used to pass parameter value of this type as parameters to called procedure
}

        ResultFreeMacro: PMacro;{ macro used to free return result from called function }
    public
        constructor Create( ASize: Longint; AConstantSymbol: PParserSymbol; AVariableSymbol: PParserSymbol; ALocalSymbol:
PParserSymbol; AParameterSymbol: PParserSymbol);
        function GetSymbolType: TSymbolType; virtual; { returns stType }
        function GetTypeSize:Word; { returns value of ~TypeSize~ }
        function GetConstantSymbol: PParserSymbol;{ returns value of ~ConstantSymbol~ }
        function GetVariableSymbol: PParserSymbol;{ returns value of ~VariableSymbol~ }
        function GetLocalSymbol: PParserSymbol;{ returns value of ~LocalSymbol~ }
        function GetParameterSymbol: PParserSymbol;{ returns value of ~ParameterSymbol~ }
        procedure SetVaraiableParameterInitMacro( AMacro: PMacro);{ set value of ~VariableParameterInitMacro~ }
        procedure SetConstantParameterInitMacro( AMacro: PMacro);{ set value of ~ConstantParameterInitMacro~ }
        procedure SetLocalParameterInitMacro( AMacro: PMacro);{ set value of ~LocalParameterInitMacro~ }
        procedure SetParameterParameterInitMacro( AMacro: PMacro);{ set value of ~ParameterParameterInitMacro~ }
        function GetVaraiableParameterInitMacro: PMacro;{ return value of ~VariableParameterInitMacro~ }
        function GetConstantParameterInitMacro: PMacro;{ return value of ~ConstantParameterInitMacro~ }
        function GetLocalParameterInitMacro: PMacro;{ return value of ~LocalParameterInitMacro~ }
        function GetParameterParameterInitMacro: PMacro;{ return value of ~ParameterParameterInitMacro~ }
        procedure SetResultFreeMacro(AMacro: PMacro);{ set value of ~ResultFreeMacro~ }
        function GetResultFreeMacro: PMacro;{ return value of ~ResultFreeMacro~ }
        end;

    { symbol table entry attributes for block name used in map defination }
    PBlockRecord = ^TBlockRecord;
    TBlockRecord = object( TSymbolAttributes)
    private
        BlockMacro: PMacro; { macro of this block }
    public
        constructor Create( ABlockMacro: PMacro);
        function GetSymbolType: TSymbolType; virtual;{ returns ~stBlock~ }
        function GetBlockMacro: PMacro;{ returns the valuue of ~BlockMacro~ }
        end;

    { symbol table entry attributes for extra symbol used in rules of sub expresion define, it is used as meta symbol in gramma
r and it has no attributes during translation process }
    PExtraSymbolRecord = ^TExtraSymbolRecord;
    TExtraSymbolRecord = object( TSymbolAttributes)
    private
        Symbol: PParserSymbol;
    public
       constructor Create( ASymbol: PParserSymbol);
       function GetSymbolType: TSymbolType; virtual;
       function GetSymbol: PParserSymbol;
       end;

    { object contains all properties of any memory variable in a any data block, it created while defining each global variable
 in translation stage }
    PVarRecord = ^TVarRecord;
    TVarRecord = object( TGeneric)
    private
        VarSize: Longint; { variable size in esantial target machine words, it calculated from its type size and count of word}
        VarOffset: Longint; { offset of variable in data block }
        VarBackOffset: Longint; { offset of variable in data block from the end of all global data }
    public
        constructor Create( AVarSize: Longint);
        function GetVarSize: Longint;
        procedure SetVarOffset( AOffset: Longint);
        function GetVarOffset: Longint;
        procedure SetVarBackOffset( AOffset: Longint);
        function GetVarBackOffset: Longint;
        end;

    { object contains all properties of global defined var, it created while defining each global variable in translation stage
 }
    PGlobalVarRecord = ^TGlobalVarRecord;
    TGlobalVarRecord = object( TVarRecord)
        end;

    { object contains all properties of local defined var in current translated procedure, it created while defining each local
 variable in translation stage }
    PLocalVarRecord = ^TLocalVarRecord;
    TLocalVarRecord = object( TGlobalVarRecord)
        end;

    { object contains all properties of parameter var in current translated procedure, it created while defining each parameter
 in translation stage }
    PParameterRecord = ^TParameterRecord;
    TParameterRecord = object( TGlobalVarRecord)
        end;

    { record hlods information about parameter passed to called procedure }
    TCallPrameterInfo = record
        CallParamTypeRecord: PTypeRecord;
        case CallParamType: TCallParam of
         cpConst: ( Value: Longint);
         cpGlobal: ( GlobalId: Longint);
         cpLocal: ( LocalId: Longint);
         cpParam: ( ParamId: Longint);
         end;


    { object hlods information about parameter passed to called procedure, it created while passing each parameter to procedure
 in call building in translation stage }
    PCallParameter = ^TCallParameter;
    TCallParameter = object( TGeneric)
    private
        CallParamInfo: TCallPrameterInfo;
    public
        constructor CreateConstant( AType: PTypeRecord; AValue: Longint);
        constructor CreateGlobal( AType: PTypeRecord; AId: Longint);
        constructor CreateLocal( AType: PTypeRecord; AId: Longint);
        constructor CreateParam( AType: PTypeRecord; AId: Longint);

        function GetCallParamType: TCallParam;
        function GetTypeRecord: PTypeRecord;
        function GetConstantValue: Longint;
        function GetGlobalId: Longint;
        function GetLocalId: Longint;
        function GetParamId: Longint;
        end;

    { abstract object type of symbol attributes that readed from source translated file, this symbol may have many attributes,
each one of symbols attribute has a name that could be retrived by use it against with the symbol number in the rule, this attr
ibute used in the defining of parameters calculation expresion of macro }
    PSourceSymbolAttr = ^TSourceSymbolAttr;
    TSourceSymbolAttr = object( TGeneric)
    public
        function GetAttribute( AAttribute: string): Longint; virtual;
        end;

    { object type that holds an attributes of a global variable, it created after reading a global var symbol from a source fil
e an passed to the parser with the ~TParserSymbol~ object, and the parser holds in parser stack withot use until reduce operati
on, it pass the collection of this objects to macro emeter method }
    PGlobalSymbolAttr = ^TGlobalSymbolAttr;
    TGlobalSymbolAttr = object( TSourceSymbolAttr)
    private
        GlobalVarRecord: PGlobalVarRecord;
    public
        constructor Create( AGlobalVarRecord: PGlobalVarRecord);
        function GetAttribute( AAttribute: string): Longint; virtual;
        end;

    { like pevios but for local symbol readen from source file }
    PLocalSymbolAttr = ^TLocalSymbolAttr;
    TLocalSymbolAttr = object( TSourceSymbolAttr)
    private
        LocalVarRecord: PLocalVarRecord;
    public
        constructor Create( ALocalVarRecord: PLocalVarRecord);
        function GetAttribute( AAttribute: string): Longint; virtual;
        end;

    { like pevios but for parameter symbol readen from source file }
    PParameterSymbolAttr = ^TParameterSymbolAttr;
    TParameterSymbolAttr = object( TSourceSymbolAttr)
    private
        ParameterRecord: PParameterRecord;
    public
        constructor Create( AParameterRecord: PParameterRecord);
        function GetAttribute( AAttribute: string): Longint; virtual;
        end;

    { like pevios but for constant symbol readen from source file }
    PConstantSymbolAttr = ^TConstantSymbolAttr;
    TConstantSymbolAttr = object( TSourceSymbolAttr)
    private
        ConstantValue: Longint;
    public
        constructor Create( AConstantValue: Longint);
        function GetAttribute( AAttribute: string): Longint; virtual;
        end;

    { like pevios but for id number symbol readen from source file }
    PIDSymbolAttr = ^TIDSymbolAttr;
    TIDSymbolAttr = object( TSourceSymbolAttr)
    private
        ID: Longint;
    public
        constructor Create( AID: Longint);
        function GetAttribute( AAttribute: string): Longint; virtual;
        end;


    PTranslator = ^TTranslator;

    { modified parser object type to make it work with ~TTranslator~ object }
    PTranslatorParser = ^TTranslatorParser;
    TTranslatorParser = object( TParser)
    private
        Owner : PTranslator;
        OutputStream: PStream;
    public
        constructor Create( AOwner: PTranslator; ASymbols: PCollection; AGrammar: PGrammar; AOutputStream: PStream);
        procedure SetOutputStream( AOutputStream: PStream);{ used to link the ouput file with parser }
        procedure GenerateOutput( ARule: PRule; AAttributes:PCollection);
         virtual;{ method that emit macro body to output file }
        end;

    { record encapsulate the variables of translator tha can be used in macros parameters, and there is a member variable in ~T
Translator~ object from this type}
    TTranslationVariables = record
         { Variables used globaly during translation }
        ProcedureID               : Longint;{ the id of current procedure }
        GlobalDataSize            : Longint;{ global data size defined in translated program }
        LocalDataSize             : Longint;{ local data size defined in translated program in procedur section }
        ParametersDataSize        : Longint;{ parameters data size defined in translated program in procedur section }
        ReturnDataSize            : Longint;{ return data size defined in translated program in procedur section }

         { Variables used when creating a proedure call }
         { These variables identify the parameter attribute related to passed parameters block (or set) }
        ParametersBlockSize       : Longint;{ Passed parameters data size }
        CallParametersCount       : Longint;{ Passed parameters count }
        CallParameterOffset       : Longint;{ Current parameter offset in parameters block }
        CallParameterNo           : Longint;{ Current parameter no in the call parameters set }

        GlobalID                  : Longint;{ If current parameter is a global variable, it keep it`s id }
        GlobalOffset              : Longint;{ If current parameter is a global variable, it keep it`s offset }
         { *** Must append back offset *** }
        LocalID                   : Longint;{ If current parameter is a local variable in a procedure, it keep it`s id }
        LocalOffset               : Longint;{ If current parameter is a local variable in a procedure, it keep it`s offset }
         { *** Must append back offset *** }
        ParamID                   : Longint;{ If current parameter is a passed parameter to current procedure, it keep it`s id}
        ParamOffset               : Longint;{ If current parameter is a passed parameter to current procedure, it keep it`s off
set }
        ConstantValue             : Longint;{ If current parameter is a constant, it keep it`s value }
        CalledProcedureID         : Longint;{ It keep the called procedure id }
         { *** Must append back offset *** }
        end;

    TMaps = record
        GlobalMap               : TMap;
        MainMap                 : TMap;
        ProcedureMap            : TMap;
        ProcedureCallMap        : TMap;
        end;

    TDefinesDataBase = record
        ParserSymbols: TContainerCollection;{ all ~TParserSymbol~ object that created and passed to the ~TParser~ object for cr
eation the dynamic parser, and used to create the grammar of the parser }
        ParserGrammar: TGrammar;{ descripe the grammar that generate the expretions parser }
        Macros: TContainerCollection;{ all macros that defined in defination file }
        SymbolsTable: TSymbolsTable;{ table of all symbols used by the parser and translator each entry have an attributes hold
ed by the ~TSymbolAttributes~ object or its ancestors }
        IDParserSymbol: PParserSymbol;
        Maps: TMaps;
        end;

    TranslationDataBase = record
        GlobalVars: TContainerCollection;{ collection of ~TGlobalVarRecord~ objects is used in the all source program after def
ine it}
        LocalVars: TContainerCollection;{ collection of ~TLocalVarRecord~ objects it is used in the procedure translation stage
}
        Parameters: TContainerCollection;{ collection of ~TParameterRecord~ objects, it is used in the procedure translation st
age}
        CallParameters: TContainerCollection;{ collection of ~TCallPrameterInfo~ objects it is used in call building stage }
        CurrentResultType: PTypeRecord;{ pointer to current result returned from last function that stored in stack}
        end;

    TTranslator = object( TTopErrGeneric)
    public
        DefinesDataBase: TDefinesDataBase;{ all information that retrived from reading defines file }
        TranslationDataBase: TranslationDataBase;{ all information that retrived during translation stage }
        TranslationVars: TTranslationVariables;
        Parser: TTranslatorParser;{ Variables used in calling parameters initialising macros }
        procedure ClearParserSymbols;
{$IFDEF DEBUGSTATE}
        function CreateParserSymbol( ATitle: string): PParserSymbol;
{$ELSE}
        function CreateParserSymbol: PParserSymbol;
{$ENDIF}
        procedure ClearMocros;
        procedure ClearGrammar;
        procedure AppendRule( ARule: PRule);
        procedure AppendMacro( AMacro: PMacro);

        procedure ClearSymbolsTable;
        function AppendSymbol( AIdentifier: string; AAttributes: PSymbolAttributes): Boolean;
        function GetSymbolsAttributes( AIdentifier: string): PSymbolAttributes;
        function MatchSymbol( ASource: PSource; AType: TSymbolType; AErrorActive: Boolean): PSymbolAttributes;
        function ReadInteger( ASource: PSource; var AValue: Longint): Boolean;
        function IsDefinedSymbol( AIdentifier: string): Boolean;
        function AppendType( AIdentifier: string; ATypeSize: Longint): Boolean;
        function AppendOperation( AIdentifier: string): Boolean;
        function AppendExtraSymbol( AIdentifier: string): Boolean;
        function AppendVariable( AIdentifier: string; AValueInfo: PValueInfo): Boolean;
        function AppendBlock( AIdentifier: string;ABlockMacro: PMacro): Boolean;
        procedure ClearGlobalInfo;
        procedure AppendGlobalVar( AVar: PGlobalVarRecord);
        function GetGlobalVar( AIndex: Longint): PGlobalVarRecord;
        procedure FinalGlobalsCalculations;
        function GetGlobalDataSize: Longint;
        procedure ClearLocalInfo;
        procedure AppendLocalVar( ALocal: PLocalVarRecord);
        function GetLocalVar( AIndex: Longint): PLocalVarRecord;
        procedure AppendParameter( AParameter: PParameterRecord);
        function GetParameter( AIndex: Longint): PParameterRecord;
        procedure FinalLocalsCalculations;
        procedure ClearCallInfo;
        procedure AppendCallParameter( ACallParameter: PCallParameter);
        function GetCallParameter( AIndex: Longint): PCallParameter;
        procedure FinalCallParametersCalculations;
    public
        constructor Create;
        destructor Destroy;virtual;
        procedure ReadDefinesFile( AFileName: string);
        procedure ClearError;
        procedure TranslateFile( InputFileName: string; OutputFileName: string);
{$IFDEF DEBUGSTATE}
        procedure Debug;
{$ENDIF}
        end;


    PVarValueInfo = ^TVarValueInfo;
    TVarValueInfo = object( TValueInfo)
    private
        TheVar: PLongint;
    public
        constructor Create( AVar: PLongint);
        function GetValue: Longint; virtual;
        procedure SetVar( AVar: PLongint);
        end;


function TSymbolAttributes.GetSymbolType: TSymbolType;
begin
     GetSymbolType := stNone;
end;


constructor TVariableRecord.Create( AValueInfo: PValueInfo);
begin
     inherited Create;
     ValueInfo := AValueInfo;
end;

destructor TVariableRecord.Destroy;
begin
     if (ValueInfo <> nil)
     then ValueInfo^.Free;
     inherited Destroy;
end;

function TVariableRecord.GetSymbolType: TSymbolType;
begin
     GetSymbolType := stVariable;
end;

function TVariableRecord.GetValueInfo: PValueInfo;
begin
     GetValueInfo := ValueInfo;
end;


constructor TOperationRecord.Create( ASymbol: PParserSymbol);
begin
     inherited Create;
     OperationSymbol := ASymbol;
end;

function TOperationRecord.GetSymbolType: TSymbolType;
begin
     GetSymbolType := stOperation;
end;

function TOperationRecord.GetSymbol: PParserSymbol;
begin
     GetSymbol := OperationSymbol;
end;


Constructor TTypeRecord.Create( ASize: Longint; AConstantSymbol: PParserSymbol; AVariableSymbol: PParserSymbol; ALocalSymbol:
PParserSymbol; AParameterSymbol: PParserSymbol);
begin
     inherited Create;
     TypeSize := ASize;
     ConstantSymbol := AConstantSymbol;
     VariableSymbol := AVariableSymbol;
     LocalSymbol := ALocalSymbol;
     ParameterSymbol := AParameterSymbol;
     VariableParameterInitMacro := nil;
     ConstantParameterInitMacro := nil;
     LocalParameterInitMacro := nil;
     ParameterParameterInitMacro := nil;
     ResultFreeMacro := nil;
end;

function TTypeRecord.GetSymbolType: TSymbolType;
begin
     GetSymbolType := stType;
end;

function TTypeRecord.GetTypeSize: Word;
begin
     GetTypeSize := TypeSize;
end;

function TTypeRecord.GetConstantSymbol: PParserSymbol;
begin
     GetConstantSymbol := ConstantSymbol;
end;

function TTypeRecord.GetVariableSymbol: PParserSymbol;
begin
     GetVariableSymbol := VariableSymbol;
end;

function TTypeRecord.GetLocalSymbol: PParserSymbol;
begin
     GetLocalSymbol := LocalSymbol;
end;

function TTypeRecord.GetParameterSymbol: PParserSymbol;
begin
     GetParameterSymbol := ParameterSymbol;
end;

procedure TTypeRecord.SetVaraiableParameterInitMacro( AMacro: PMacro);
begin
     VariableParameterInitMacro := AMacro;
end;

function TTypeRecord.GetVaraiableParameterInitMacro: PMacro;
begin
     GetVaraiableParameterInitMacro := VariableParameterInitMacro;
end;

procedure TTypeRecord.SetConstantParameterInitMacro( AMacro: PMacro);
begin
     ConstantParameterInitMacro := AMacro;
end;

function TTypeRecord.GetConstantParameterInitMacro: PMacro;
begin
     GetConstantParameterInitMacro := ConstantParameterInitMacro;
end;

procedure TTypeRecord.SetLocalParameterInitMacro( AMacro: PMacro);
begin
     LocalParameterInitMacro := AMacro;
end;

function TTypeRecord.GetLocalParameterInitMacro: PMacro;
begin
     GetLocalParameterInitMacro := LocalParameterInitMacro;
end;

procedure TTypeRecord.SetParameterParameterInitMacro( AMacro: PMacro);
begin
     ParameterParameterInitMacro := AMacro;
end;

function TTypeRecord.GetParameterParameterInitMacro: PMacro;
begin
     GetParameterParameterInitMacro := ParameterParameterInitMacro;
end;

procedure TTypeRecord.SetResultFreeMacro( AMacro: PMacro);
begin
     ResultFreeMacro := AMacro;
end;

function TTypeRecord.GetResultFreeMacro: PMacro;
begin
     GetResultFreeMacro := ResultFreeMacro;
end;


constructor TBlockRecord.Create( ABlockMacro: PMacro);
begin
     inherited Create;
     BlockMacro := ABlockMacro;
end;

function TBlockRecord.GetBlockMacro: PMacro;
begin
     GetBlockMacro := BlockMacro;
end;

function TBlockRecord.GetSymbolType: TSymbolType;
begin
     GetSymbolType := stBlock;
end;


constructor TExtraSymbolRecord.Create( ASymbol: PParserSymbol);
begin
     inherited Create;
     Symbol := ASymbol;
end;

function TExtraSymbolRecord.GetSymbolType: TSymbolType;
begin
     GetSymbolType := stExtraSymbol;
end;

function TExtraSymbolRecord.GetSymbol: PParserSymbol;
begin
     GetSymbol := Symbol;
end;


constructor TVarRecord.Create( AVarSize: Longint);
begin
     inherited Create;
     VarSize := AVarSize;
end;

function TVarRecord.GetVarSize: Longint;
begin
     GetVarSize := VarSize;
end;

procedure TVarRecord.SetVarOffset( AOffset: Longint);
begin
     VarOffset := AOffset;
end;

function TVarRecord.GetVarOffset: Longint;
begin
     GetVarOffset := VarOffset;
end;

procedure TVarRecord.SetVarBackOffset( AOffset: Longint);
begin
     VarBackOffset := AOffset;
end;

function TVarRecord.GetVarBackOffset: Longint;
begin
     GetVarBackOffset := VarBackOffset;
end;


constructor TCallParameter.CreateConstant( AType: PTypeRecord; AValue: Longint);
begin
     inherited Create;
     CallParamInfo.CallParamTypeRecord := AType;
     CallParamInfo.CallParamType := cpConst;
     CallParamInfo.Value := AValue;
end;

constructor TCallParameter.CreateGlobal( AType: PTypeRecord; AId: Longint);
begin
     inherited Create;
     CallParamInfo.CallParamTypeRecord := AType;
     CallParamInfo.CallParamType := cpGlobal;
     CallParamInfo.GlobalId := AId;
end;

constructor TCallParameter.CreateLocal( AType: PTypeRecord; AId: Longint);
begin
     inherited Create;
     CallParamInfo.CallParamTypeRecord := AType;
     CallParamInfo.CallParamType := cpLocal;
     CallParamInfo.LocalId := AId;
end;

constructor TCallParameter.CreateParam( AType: PTypeRecord; AId: Longint);
begin
     inherited Create;
     CallParamInfo.CallParamTypeRecord := AType;
     CallParamInfo.CallParamType := cpParam;
     CallParamInfo.ParamId := AId;
end;

function TCallParameter.GetCallParamType: TCallParam;
begin
     GetCallParamType := CallParamInfo.CallParamType;
end;

function TCallParameter.GetTypeRecord: PTypeRecord;
begin
     GetTypeRecord := CallParamInfo.CallParamTypeRecord;
end;

function TCallParameter.GetConstantValue: Longint;
begin
     GetConstantValue := CallParamInfo.Value;
end;

function TCallParameter.GetGlobalId: Longint;
begin
     GetGlobalId := CallParamInfo.GlobalId
end;

function TCallParameter.GetLocalId: Longint;
begin
     GetLocalId := CallParamInfo.LocalId
end;

function TCallParameter.GetParamId: Longint;
begin
     GetParamId := CallParamInfo.ParamId
end;


constructor TMacroParameter.Create( AOwner: PErrGeneric; APosition: Word);
begin
     inherited Create( AOwner);
     Position := APosition;
     ExtraInfo := nil;
end;

destructor TMacroParameter.Destroy;
begin
     Inherited Destroy;
end;

function TMacroParameter.ParseExpresion( AExpresion: string; ASymbolsTable: PSymbolsTable): Boolean;
begin
     if (Length(AExpresion) > 0)
     then begin
          ExtraInfo := ASymbolsTable;
          ParseExpresion := Build( AExpresion);
          end
     else ParseExpresion := True;
end;

function TMacroParameter.GetVariableInfo( AVarStr: string): PValueInfo;
var SymbolAttributes: PSymbolAttributes;
begin
     GetVariableInfo := nil;
     if ( ExtraInfo <> nil)
     then begin
          SymbolAttributes := PSymbolAttributes( PSymbolsTable( ExtraInfo)^.Find( AVarStr));
          if ( SymbolAttributes <> nil)
          then begin
               if ( SymbolAttributes^.GetSymbolType = stVariable)
               then GetVariableInfo := PVariableRecord( SymbolAttributes)^.GetValueInfo;
               end
          else AddError( New( PMessageError,Create( 'EXPRESION ERROR: Bad expresion variable ~' + AVarStr + '~ .')));

          end;
end;

function TMacroParameter.GetParameterValue( AParamID: Word; AParamAttrib: string): Longint;
var MacroParamValue: PSourceSymbolAttr;
begin
     GetParameterValue := 0;
     if ( ExtraInfo <> nil)
     then begin
          MacroParamValue:= PSourceSymbolAttr( PCollection( ExtraInfo)^.GetByIndex( AParamID));
          if ( MacroParamValue <> nil)
          then GetParameterValue := MacroParamValue^.GetAttribute( AParamAttrib);
          end;
end;

function TMacroParameter.GetPosition: Word;
begin
     GetPosition := Position;
end;

function TMacroParameter.GetOutput( AParameters: PCollection): string;
var Value: Longint;
    TempStr: string;
begin
     ExtraInfo := AParameters;
     Value := Evaluate;
     Str( Value, TempStr);
     GetOutput := TempStr;
end;


constructor TMacro.Create( AOwner: PErrGeneric);
var ScanPtr: PChar;
    ParameterStart: PChar;
    ScannedSize: Word;
    ActualSize: Word;
    State: Word;
begin
     inherited Create( AOwner);
     Parameters.Create;
     MacroBodySize := 0;
     MacroBody := nil;
end;

destructor TMacro.Destroy;
begin
     Parameters.Clear;
     if (( MacroBody <> nil) and ( MacroBodySize > 0))
     then FreeMem( MacroBody, MacroBodySize);
     MacroBody := nil;
     MacroBodySize := 0;
     inherited Destroy;
end;

function TMacro.Build( ASymbolsTable: PSymbolsTable; ABody: PChar; ASize: Word): Boolean;
var ScanPtr: PChar;
    ParameterStart: PChar;
    ScannedSize: Word;
    ActualSize: Word;
    State: Word;
    ParamLength: Word;
    ParamString: string;
    Code: Integer;
    ParamIntegerValue: Word;
    DraftBody: PChar;
    DraftCursor: PChar;
    MacroParameter: PMacroParameter;
begin
     Parameters.Clear;
     if (( MacroBody <> nil) and ( MacroBodySize > 0))
     then FreeMem( MacroBody, MacroBodySize);
     MacroBody := nil;
     MacroBodySize := 0;
     Build := False;
     if (( ABody <> nil) and ( ASize > 0))
     then begin
          GetMem( DraftBody, ASize);
          DraftCursor := DraftBody;
          State := 0;
          ScanPtr := ABody;
          ScannedSize := 0;
          ActualSize := 0;
          while ( ScannedSize < ASize)
          do begin
             case State of
             0: begin
                if ( ScanPtr^ <> '#')
                then begin
                     ActualSize := ActualSize + 1;
                     DraftCursor^ := ScanPtr^;
                     DraftCursor := DraftCursor + 1;
                     end
                else State := 1;
                ScannedSize := ScannedSize + 1;
                ScanPtr := ScanPtr + 1;
                end;
             1: begin
                if ( ScanPtr^ = '#')
                then State := 2
                else begin
                     ActualSize := ActualSize + 2;
                     DraftCursor^ := '#';
                     DraftCursor := DraftCursor + 1;
                     DraftCursor^ := ScanPtr^;
                     DraftCursor := DraftCursor + 1;
                     State := 0;
                     end;
                ScannedSize := ScannedSize + 1;
                ScanPtr := ScanPtr + 1;
                end;
             2: begin
                if ( ScanPtr^ = '<')
                then State := 3
                else begin
                     if ( ScanPtr^ = '#')
                     then begin
                          DraftCursor^ := '#';
                          DraftCursor := DraftCursor + 1;
                          ActualSize := ActualSize + 1
                          {State := 2;}
                          end
                     else begin
                          DraftCursor^ := '#';
                          DraftCursor := DraftCursor + 1;
                          DraftCursor^ := '#';
                          DraftCursor := DraftCursor + 1;
                          DraftCursor^ := ScanPtr^;
                          DraftCursor := DraftCursor + 1;
                          ActualSize := ActualSize + 3;
                          State := 0;
                          end;
                     end;
                ScannedSize := ScannedSize + 1;
                ScanPtr := ScanPtr + 1;
                end;
             3: begin
                ParameterStart := ScanPtr;
                State := 4;
                if (ScanPtr^ = '>')
                then State := 5
                else begin
                     ScannedSize := ScannedSize + 1;
                     ScanPtr := ScanPtr + 1;
                     end;
                end;
             4: begin
                if (ScanPtr^ = '>')
                then State := 5
                else begin
                     ScannedSize := ScannedSize + 1;
                     ScanPtr := ScanPtr + 1;
                     end;
                end;
             5: begin
                ParamLength := ScanPtr - ParameterStart;
                ScannedSize := ScannedSize + 1;
                ScanPtr := ScanPtr + 1;
                if (( ParamLength < 256) and ( ParamLength > 0))
                then begin
                     Move( ParameterStart^, ParamString[1], ParamLength);
                     ParamString[0] := Char( ParamLength);
                     MacroParameter := New( PMacroParameter, Create(@Self, ActualSize));
                     if ( MacroParameter^.ParseExpresion( ParamString, ASymbolsTable))
                     then begin
                          Parameters.PushLast( MacroParameter);
                          State := 0;
                          end
                     else begin
                          MacroParameter^.Free;
                          break;
                          end;
                     end
                else break;
                end;
             end;{ case }
             end;{ while }
          if State = 0
          then begin
               Build := True;
               GetMem( MacroBody, ActualSize);
               Move( DraftBody^, MacroBody^, ActualSize);
               MacroBodySize := ActualSize;
               end
          else Parameters.Clear;
          FreeMem( DraftBody, ASize);
          end;
end;

{$IFDEF DEBUGSTATE}

procedure TMacro.Display;
var Param: PMacroParameter;
    DisplayedSize: Word;
    ScanPtr: PChar;
    StopPos: Word;
begin
     if (( MacroBody <> nil) and ( MacroBodySize > 0))
     then begin
          Param := PMacroParameter( Parameters.GetFirst);
          DisplayedSize := 0;
          ScanPtr := MacroBody;
          while (Param <> nil)
          do begin
             StopPos := Param^.GetPosition;
             while (( DisplayedSize < MacroBodySize) and ( DisplayedSize < StopPos))
             do begin
                Write( DebugOutput, ScanPtr^);
                ScanPtr := ScanPtr + 1;
                DisplayedSize := DisplayedSize + 1;
                end;
             Write( DebugOutput, Param^.GetOutput( nil));
             Param := PMacroParameter( Parameters.GetNext);
             end;
          while ( DisplayedSize < MacroBodySize)
          do begin
             Write( DebugOutput,ScanPtr^);
             ScanPtr := ScanPtr + 1;
             DisplayedSize := DisplayedSize + 1;
             end;
          end;
end;
{$ENDIF}

procedure TMacro.GenerateOutput( AOutputStream: PStream; AAttributes: PCollection);
var Param: PMacroParameter;
    DisplayedSize: Word;
    ScanPtr: PChar;
    StopPos: Word;
    ExprStr: string;
begin
     if (( AOutputStream <> nil) and ( MacroBody <> nil) and ( MacroBodySize > 0))
     then begin
          Param := PMacroParameter( Parameters.GetFirst);
          DisplayedSize := 0;
          ScanPtr := MacroBody;
          while ( Param <> nil)
          do begin
             StopPos := Param^.GetPosition;
             while (( DisplayedSize < MacroBodySize) and ( DisplayedSize < StopPos))
             do begin
                AOutputStream^.Write( ScanPtr^,1);
                ScanPtr := ScanPtr + 1;
                DisplayedSize := DisplayedSize + 1;
                end;
             ExprStr := Param^.GetOutput( AAttributes);
             AOutputStream^.Write( ExprStr[1], Length( ExprStr));
             Param := PMacroParameter( Parameters.GetNext);
             end;
          while (DisplayedSize < MacroBodySize)
          do begin
             AOutputStream^.Write( ScanPtr^,1);
             ScanPtr := ScanPtr + 1;
             DisplayedSize := DisplayedSize + 1;
             end;
          end;
end;


constructor TMapItem.Create( AItemType: TMapItemType; AMacro: PMacro);
begin
     inherited Create;
     ItemType := AItemType;
     Macro := AMacro;
end;

function TMapItem.GetItemType: TMapItemType;
begin
     GetItemType := ItemType;
end;

function TMapItem.GetMacro: PMacro;
begin
     GetMacro := Macro;
end;


constructor TMap.Create;
begin
     inherited Create;
     Items.Create;
end;

destructor TMap.Destroy;
begin
     Items.Destroy;
     inherited Destroy;
end;

procedure TMap.Append( AItem: PMapItem);
begin
     Items.PushLast( AItem);
end;

function TMap.GetFirst: PMapItem;
begin
     GetFirst := PMapItem( Items.GetFirst);
end;

function TMap.GetNext: PMapItem;
begin
     GetNext := PMapItem( Items.GetNext);
end;


function TSourceSymbolAttr.GetAttribute( AAttribute: string): Longint;
begin
     GetAttribute := 10001;
end;


constructor TGlobalSymbolAttr.Create( AGlobalVarRecord: PGlobalVarRecord);
begin
     inherited Create;
     GlobalVarRecord := AGlobalVarRecord;
end;

function TGlobalSymbolAttr.GetAttribute( AAttribute: string): Longint;
begin
     if (GlobalVarRecord <> nil)
     then begin
          if AAttribute = OFFSET_ATTR
          then GetAttribute := GlobalVarRecord^.GetVarOffset
          else if AAttribute = BACKOFFSET_ATTR
          then GetAttribute := GlobalVarRecord^.GetVarBackOffset
          else if AAttribute = SIZE_ATTR
          then GetAttribute := GlobalVarRecord^.GetVarSize
          else GetAttribute := 0;
          end
     else GetAttribute := 0;
end;


constructor TLocalSymbolAttr.Create( ALocalVarRecord: PLocalVarRecord);
begin
     inherited Create;
     LocalVarRecord := ALocalVarRecord;
end;

function TLocalSymbolAttr.GetAttribute( AAttribute: string): Longint;
begin
     if (LocalVarRecord <> nil)
     then begin
          if AAttribute = OFFSET_ATTR
          then GetAttribute := LocalVarRecord^.GetVarOffset
          else if AAttribute = BACKOFFSET_ATTR
          then GetAttribute := LocalVarRecord^.GetVarBackOffset
          else if AAttribute = SIZE_ATTR
          then GetAttribute := LocalVarRecord^.GetVarSize
          else GetAttribute := 0;
          end
     else GetAttribute := 0;
end;


constructor TParameterSymbolAttr.Create( AParameterRecord: PParameterRecord);
begin
     inherited Create;
     ParameterRecord := AParameterRecord;
end;

function TParameterSymbolAttr.GetAttribute( AAttribute: string): Longint;
begin
     if (ParameterRecord <> nil)
     then begin
          if AAttribute = OFFSET_ATTR
          then GetAttribute := ParameterRecord^.GetVarOffset
          else if AAttribute = BACKOFFSET_ATTR
          then GetAttribute := ParameterRecord^.GetVarBackOffset
          else if AAttribute = SIZE_ATTR
          then GetAttribute := ParameterRecord^.GetVarSize
          else GetAttribute := 0;
          end
     else GetAttribute := 0;
end;


constructor TConstantSymbolAttr.Create( AConstantValue: Longint);
begin
     inherited Create;
     ConstantValue := AConstantValue;
end;

function TConstantSymbolAttr.GetAttribute( AAttribute: string): Longint;
begin
     if AAttribute = VALUE_ATTR
     then GetAttribute := ConstantValue
     else GetAttribute := 0;
end;


constructor TIDSymbolAttr.Create( AID: Longint);
begin
     inherited Create;
     ID := AID;
end;

function TIDSymbolAttr.GetAttribute( AAttribute: string): Longint;
begin
     if AAttribute = ID_ATTR
     then GetAttribute := ID
     else GetAttribute := 0;
end;


constructor TTranslatorParser.Create( AOwner: PTranslator; ASymbols: PCollection; AGrammar: PGrammar; AOutputStream: PStream);
begin
     inherited Create( AOwner ,ASymbols, AGrammar);
     Owner := AOwner;
     OutputStream := AOutputStream;
end;

procedure TTranslatorParser.SetOutputStream( AOutputStream: PStream);
begin
     OutputStream := AOutputStream;
end;

procedure TTranslatorParser.GenerateOutput( ARule: PRule; AAttributes: PCollection);
begin
     if (ARule^.GetReduceInfo <> nil)
     then PMacro( ARule^.GetReduceInfo)^.GenerateOutput( OutputStream, AAttributes);
end;


procedure TTranslator.ClearParserSymbols;
begin
     DefinesDataBase.ParserSymbols.Clear;
end;

{$IFDEF DEBUGSTATE}
function TTranslator.CreateParserSymbol( ATitle: string): PParserSymbol;
{$ELSE}
function TTranslator.CreateParserSymbol: PParserSymbol;
{$ENDIF}
var NewParserSymbol: PParserSymbol;
begin
{$IFDEF DEBUGSTATE}
     NewParserSymbol := New( PParserSymbol, Create( DefinesDataBase.ParserSymbols.GetItemsCount + 1, ATitle));
{$ELSE}
     NewParserSymbol := New( PParserSymbol, Create( DefinesDataBase.ParserSymbols.GetItemsCount + 1));
{$ENDIF}
     DefinesDataBase.ParserSymbols.PushLast( NewParserSymbol);
     CreateParserSymbol := NewParserSymbol;
end;


procedure TTranslator.ClearMocros;
begin
     DefinesDataBase.Macros.Clear;
end;

procedure TTranslator.ClearGrammar;
begin
     DefinesDataBase.ParserGrammar.Clear;
end;

procedure TTranslator.AppendRule( ARule: PRule);
begin
     if (ARule <> nil)
     then DefinesDataBase.ParserGrammar.AppendRule( ARule);
end;

procedure TTranslator.AppendMacro( AMacro: PMacro);
begin
     if (AMacro <> nil)
     then DefinesDataBase.Macros.PushLast( AMacro);
end;

procedure TTranslator.ClearSymbolsTable;
begin
     DefinesDataBase.SymbolsTable.Clear;
end;

function TTranslator.AppendSymbol( AIdentifier: string; AAttributes: PSymbolAttributes): Boolean;
begin
     if (( AIdentifier <> '') and ( AAttributes <> nil))
     then begin
          if ( GetSymbolsAttributes( AIdentifier) = nil)
          then begin
               DefinesDataBase.SymbolsTable.Insert( AIdentifier, AAttributes);
               AppendSymbol := True;
               end
          else AppendSymbol := False;
          end
     else AppendSymbol := False;
end;

function TTranslator.GetSymbolsAttributes( AIdentifier: string): PSymbolAttributes;
begin
     GetSymbolsAttributes := PSymbolAttributes( DefinesDataBase.SymbolsTable.Find( AIdentifier));
end;

function TTranslator.MatchSymbol( ASource: PSource; AType: TSymbolType; AErrorActive: Boolean): PSymbolAttributes;
    procedure ErrorReading;
    begin
         if AErrorActive
         then begin
              case AType of
                   stVariable: AddError(New(PMessageError, Create( 'ERROR: Variable identifier expected ~' +
ASource^.LexicanString + '~.')));
                   stOperation: AddError(New(PMessageError, Create( 'ERROR: Operation identifier expected ~' +
ASource^.LexicanString + '~.')));
                   stType: AddError(New(PMessageError, Create( 'ERROR: Type identifier expected ~' + ASource^.LexicanString +
'~.')));
                   stExtraSymbol: AddError(New(PMessageError, Create( 'ERROR: Extra symbol identifier expected ~' +
ASource^.LexicanString + '~.')));
              else
                  AddError( New( PMessageError, Create( 'ERROR: Identifier expected ~' + ASource^.LexicanString + '~.')));
                  end;
              end;
    end;
var Attributes: PSymbolAttributes;
begin
     MatchSymbol := nil;
     if (ASource <> nil)
     then begin
          if ( ASource^.Lexican = lexIdentifier)
          then begin
               Attributes := PSymbolAttributes( DefinesDataBase.SymbolsTable.Find( ASource^.LexicanString));
               if ( Attributes <> nil)
               then begin
                    if ( Attributes^.GetSymbolType = AType)
                    then MatchSymbol := Attributes
                    else ErrorReading;
                    end
               else begin
                    ErrorReading;
                    end
               end
          else ErrorReading;
          end
     else AddError( New( PMessageError, Create( 'INTERNAL ERROR: Bad parameter.')));
end;

function TTranslator.ReadInteger( ASource: PSource; var AValue: Longint): Boolean;
var LexicantAttr: TLexicanAttribute;
begin
     ReadInteger := False;
     if (ASource <> nil)
     then begin
          if ( ASource^.NextLexican = lexInteger)
          then begin
               ASource^.GetLexicanAttribute( LexicantAttr);
               AValue := LexicantAttr.IntegerValue;
               ReadInteger := True;
               end
          else AddError( New( PMessageError, Create( 'ERROR: Integer constant expected.')));
          end
     else AddError( New( PMessageError, Create( 'INTERNAL ERROR: Bad parameter to ~MatchSymbol~ procedure.')));
end;

function TTranslator.IsDefinedSymbol( AIdentifier: string): Boolean;
begin
     IsDefinedSymbol := ( DefinesDataBase.SymbolsTable.Find( AIdentifier) <> nil);
end;

function TTranslator.AppendType( AIdentifier: string; ATypeSize: Longint): Boolean;
var ParserConstantSymbol: PParserSymbol;
    ParserVariableSymbol: PParserSymbol;
    ParserLocalSymbol: PParserSymbol;
    ParserParameterSymbol: PParserSymbol;
    NewTypeRecord: PTypeRecord;
begin
     if (( AIdentifier <> '') and (not IsDefinedSymbol( AIdentifier)))
     then begin
{$IFDEF DEBUGSTATE}
          ParserConstantSymbol := CreateParserSymbol( AIdentifier + '(CONST)');
          ParserVariableSymbol := CreateParserSymbol( AIdentifier + '(VAR)');
          ParserLocalSymbol := CreateParserSymbol( AIdentifier + '(LOCAL)');
          ParserParameterSymbol := CreateParserSymbol( AIdentifier + '(PARAMETER)');
{$ELSE}
          ParserConstantSymbol := CreateParserSymbol;
          ParserVariableSymbol := CreateParserSymbol;
          ParserLocalSymbol := CreateParserSymbol;
          ParserParameterSymbol := CreateParserSymbol;
{$ENDIF}
          if (( ParserConstantSymbol <> nil) and ( ParserVariableSymbol <> nil) and ( ParserLocalSymbol <> nil) and (
ParserParameterSymbol <> nil))
          then begin
               NewTypeRecord := New( PTypeRecord, Create( ATypeSize, ParserConstantSymbol, ParserVariableSymbol,
ParserLocalSymbol, ParserParameterSymbol));
               AppendSymbol( AIdentifier, NewTypeRecord);
               AppendType := True;
               end
          else AppendType := False;
          end
     else AppendType := False;
end;


function TTranslator.AppendOperation( AIdentifier: string): Boolean;
var ParserOperationSymbol: PParserSymbol;
    NewOperationRecord: POperationRecord;
begin
     if (( AIdentifier <> '') and (not IsDefinedSymbol( AIdentifier)))
     then begin
{$IFDEF DEBUGSTATE}
          ParserOperationSymbol := CreateParserSymbol( AIdentifier);
{$ELSE}
          ParserOperationSymbol := CreateParserSymbol;
{$ENDIF}
          if (ParserOperationSymbol <> nil)
          then begin
               NewOperationRecord := New( POperationRecord, Create( ParserOperationSymbol));
               AppendSymbol( AIdentifier, NewOperationRecord);
               AppendOperation := True;
               end
          else AppendOperation := False;
          end
     else AppendOperation := False;
end;

function TTranslator.AppendExtraSymbol( AIdentifier: string): Boolean;
var ParserExtraSymbolSymbol: PParserSymbol;
    NewExtraSymbolRecord: PExtraSymbolRecord;
begin
     if (( AIdentifier <> '') and (not IsDefinedSymbol( AIdentifier)))
     then begin
{$IFDEF DEBUGSTATE}
          ParserExtraSymbolSymbol := CreateParserSymbol( AIdentifier);
{$ELSE}
          ParserExtraSymbolSymbol := CreateParserSymbol;
{$ENDIF}
          if (ParserExtraSymbolSymbol <> nil)
          then begin
               NewExtraSymbolRecord := New( PExtraSymbolRecord, Create(ParserExtraSymbolSymbol));
               AppendSymbol( AIdentifier, NewExtraSymbolRecord);
               AppendExtraSymbol := True;
               end
          else AppendExtraSymbol := False;
          end
     else AppendExtraSymbol := False;
end;

function TTranslator.AppendVariable( AIdentifier: string; AValueInfo: PValueInfo): Boolean;
var VarRecord: PVariableRecord;
begin
     if (( AIdentifier <> '') and (not IsDefinedSymbol( AIdentifier)))
     then begin
          VarRecord := New( PVariableRecord, Create( AValueInfo));
          AppendSymbol( AIdentifier, VarRecord);
          AppendVariable := True;
          end
     else begin
          AppendVariable := False;
          AddError( New( PMessageError, Create( 'ERROR: Duplicate identifier define ~'+AIdentifier+'~.')));
          end;
end;

function TTranslator.AppendBlock( AIdentifier: string; ABlockMacro: PMacro): Boolean;
var BlockRecord: PBlockRecord;
begin
     if (( AIdentifier <> '') and (not IsDefinedSymbol( AIdentifier)))
     then begin
          BlockRecord := New( PBlockRecord, Create( ABlockMacro));
          AppendSymbol( AIdentifier, BlockRecord);
          AppendBlock := True;
          end
     else begin
          AppendBlock := False;
          AddError( New( PMessageError, Create( 'ERROR: Duplicate identifier define ~' + AIdentifier + '~.')));
          end;
end;

procedure TTranslator.ClearGlobalInfo;
begin
     TranslationVars.GlobalDataSize := 0;
     TranslationDataBase.GlobalVars.Clear;
end;

procedure TTranslator.AppendGlobalVar( AVar: PGlobalVarRecord);
begin
     if (AVar <> nil)
     then begin
          TranslationDataBase.GlobalVars.PushLast( AVar);
          AVar^.SetVarOffset( TranslationVars.GlobalDataSize);
          TranslationVars.GlobalDataSize := TranslationVars.GlobalDataSize + AVar^.GetVarSize;
          end;
end;

function TTranslator.GetGlobalVar( AIndex: Longint): PGlobalVarRecord;
begin
     GetGlobalVar := PGlobalVarRecord( TranslationDataBase.GlobalVars.GetByIndex( AIndex));
end;

procedure TTranslator.FinalGlobalsCalculations;
var TempVar: PGlobalVarRecord;
    CurrentOffset: Longint;
begin
     TempVar := PGlobalVarRecord( TranslationDataBase.GlobalVars.GetLast);
     CurrentOffset := 0;
     while (TempVar <> nil)
     do begin
        TempVar^.SetVarBackOffset( CurrentOffset);
        CurrentOffset := CurrentOffset + TempVar^.GetVarSize;
        TempVar := PGlobalVarRecord( TranslationDataBase.GlobalVars.GetPrev);
        end;
end;

function TTranslator.GetGlobalDataSize: Longint;
begin
     GetGlobalDataSize := TranslationVars.GlobalDataSize;
end;

procedure TTranslator.ClearLocalInfo;
begin
     TranslationVars.LocalDataSize := 0;
     TranslationVars.ParametersDataSize := 0;
     TranslationVars.ReturnDataSize := 0;

     TranslationVars.ParametersBlockSize := 0;
     TranslationVars.CallParametersCount := 0;
     TranslationVars.CallParameterOffset := 0;
     TranslationVars.CallParameterNo := 0;
     TranslationVars.GlobalID := 0;
     TranslationVars.GlobalOffset := 0;
     TranslationVars.LocalOffset := 0;
     TranslationVars.LocalId := 0;
     TranslationVars.ParamOffset := 0;
     TranslationVars.ParamId := 0;
     TranslationVars.ConstantValue := 0;
     TranslationVars.CalledProcedureID := 0;

     TranslationDataBase.LocalVars.Clear;
     TranslationDataBase.Parameters.Clear;
end;

procedure TTranslator.AppendLocalVar( ALocal: PLocalVarRecord);
begin
     if (ALocal <> nil)
     then begin
          TranslationDataBase.LocalVars.Pushlast( ALocal);
          ALocal^.SetVarOffset( TranslationVars.LocalDataSize);
          TranslationVars.LocalDataSize := TranslationVars.LocalDataSize + ALocal^.GetVarSize;
          end;
end;

function TTranslator.GetLocalVar(AIndex: Longint): PLocalVarRecord;
begin
     GetLocalVar := PLocalVarRecord( TranslationDataBase.LocalVars.GetByIndex(AIndex));
end;

procedure TTranslator.AppendParameter( AParameter: PParameterRecord);
begin
     if (AParameter <> nil)
     then begin
          TranslationDataBase.Parameters.Pushlast( AParameter);
          AParameter^.SetVarOffset( TranslationVars.ParametersDataSize);
          TranslationVars.ParametersDataSize := TranslationVars.ParametersDataSize + AParameter^.GetVarSize;
          end;
end;

function TTranslator.GetParameter( AIndex: Longint): PParameterRecord;
begin
     GetParameter := PParameterRecord( TranslationDataBase.Parameters.GetByIndex( AIndex));
end;

procedure TTranslator.FinalLocalsCalculations;
var TempLocal: PLocalVarRecord;
    TempParameter: PParameterRecord;
    CurrentOffset: Longint;
begin
     CurrentOffset := 0;
     TempLocal := PLocalVarRecord( TranslationDataBase.LocalVars.GetLast);
     while (TempLocal <> nil)
     do begin
        TempLocal^.SetVarBackOffset( CurrentOffset);
        CurrentOffset := CurrentOffset + TempLocal^.GetVarSize;
        TempLocal := PLocalVarRecord( TranslationDataBase.LocalVars.GetPrev);
        end;

     CurrentOffset := 0;
     TempParameter := PParameterRecord( TranslationDataBase.Parameters.GetLast);
     while (TempParameter <> nil)
     do begin
        TempParameter^.SetVarBackOffset( CurrentOffset);
        CurrentOffset := CurrentOffset + TempParameter^.GetVarSize;
        TempParameter := PParameterRecord( TranslationDataBase.Parameters.GetPrev);
        end;
end;

procedure TTranslator.ClearCallInfo;
begin
     TranslationVars.ParametersBlockSize := 0;
     TranslationVars.CallParametersCount := 0;
     TranslationVars.CallParameterOffset := 0;
     TranslationVars.CallParameterNo := 0;
     TranslationVars.GlobalID := 0;
     TranslationVars.GlobalOffset := 0;
     TranslationVars.LocalOffset := 0;
     TranslationVars.LocalId := 0;
     TranslationVars.ParamOffset := 0;
     TranslationVars.ParamId := 0;
     TranslationVars.ConstantValue := 0;
     TranslationVars.CalledProcedureID := 0;

     TranslationDataBase.CallParameters.Clear;
end;

procedure TTranslator.AppendCallParameter( ACallParameter: PCallParameter);
var ParamTypeRec: PTypeRecord;
begin
     if (ACallParameter <> nil)
     then begin
          ParamTypeRec := ACallParameter^.GetTypeRecord;
          if (ParamTypeRec <> nil)
          then begin
               TranslationDataBase.CallParameters.PushLast( ACallParameter);
               TranslationVars.ParametersBlockSize := TranslationVars.ParametersBlockSize + ParamTypeRec^.GetTypeSize;
               TranslationVars.CallParametersCount := TranslationVars.CallParametersCount + 1;
               end;
          end;
end;

function TTranslator.GetCallParameter( AIndex: Longint): PCallParameter;
begin
     GetCallParameter := PCallParameter( TranslationDataBase.CallParameters.GetByIndex( AIndex));
end;

procedure TTranslator.FinalCallParametersCalculations;
begin
end;

constructor TTranslator.Create;
begin
     inherited Create;

     DefinesDataBase.SymbolsTable.Create( 100); { 100 Hatch sets }
     DefinesDataBase.ParserSymbols.Create;
     DefinesDataBase.ParserGrammar.Create;
     Parser.Create( @Self, @DefinesDataBase.ParserSymbols, @DefinesDataBase.ParserGrammar, nil);
     DefinesDataBase.Macros.Create;
     TranslationDataBase.GlobalVars.Create;
     TranslationDataBase.LocalVars.Create;
     TranslationDataBase.Parameters.Create;
     TranslationDataBase.CallParameters.Create;

     TranslationDataBase.CurrentResultType := nil;

     TranslationVars.GlobalDataSize := 0;
     TranslationVars.LocalDataSize := 0;
     TranslationVars.ParametersDataSize := 0;
     TranslationVars.ReturnDataSize := 0;

     TranslationVars.ParametersBlockSize := 0;
     TranslationVars.CallParametersCount := 0;
     TranslationVars.CallParameterOffset := 0;
     TranslationVars.CallParameterNo := 0;
     TranslationVars.GlobalID := 0;
     TranslationVars.GlobalOffset := 0;
     TranslationVars.LocalOffset := 0;
     TranslationVars.LocalId := 0;
     TranslationVars.ParamOffset := 0;
     TranslationVars.ParamId := 0;
     TranslationVars.ConstantValue := 0;
     TranslationVars.CalledProcedureID := 0;

     DefinesDataBase.Maps.GlobalMap.Create;
     DefinesDataBase.Maps.MainMap.Create;
     DefinesDataBase.Maps.ProcedureMap.Create;
     DefinesDataBase.Maps.ProcedureCallMap.Create;
end;

destructor TTranslator.Destroy;
begin
     DefinesDataBase.Maps.GlobalMap.Destroy;
     DefinesDataBase.Maps.MainMap.Destroy;
     DefinesDataBase.Maps.ProcedureMap.Destroy;
     DefinesDataBase.Maps.ProcedureCallMap.Destroy;

     TranslationDataBase.CallParameters.Destroy;
     TranslationDataBase.Parameters.Destroy;
     TranslationDataBase.LocalVars.Destroy;
     TranslationDataBase.GlobalVars.Destroy;
     DefinesDataBase.SymbolsTable.Destroy;
     Parser.Destroy;
     DefinesDataBase.ParserGrammar.Destroy;
     DefinesDataBase.ParserSymbols.Destroy;
     DefinesDataBase.Macros.Destroy;

     inherited Destroy;
end;

procedure TTranslator.ReadDefinesFile( AFileName: string);
var DefinesFile: TFileSource;
    Identifier: String;

    function DefineType: Boolean;
    var TypeIdentifier: string;
        TypeSize: Longint;
        LexicanAttribute: TLexicanAttribute;
    begin
         DefineType := True;
         DefinesFile.NextLexican;
         while DefinesFile.Lexican = lexIdentifier
         do begin
            TypeIdentifier := DefinesFile.LexicanString;
            if ( GetSymbolsAttributes( TypeIdentifier) = nil)
            then begin
                 if ( DefinesFile.NextLexican = lexInteger)
                 then begin
                      DefinesFile.GetLexicanAttribute( LexicanAttribute);
                      TypeSize := LexicanAttribute.IntegerValue;
                      if (TypeSize > 0)
                      then begin
                           AppendType( TypeIdentifier, TypeSize);
                           DefinesFile.NextLexican;
                           DefineType := True;
                           end
                      else begin
                           AddError( New( PMessageError,Create( 'ERROR: Bad type size ~' + TypeIdentifier + '~ .')));
                           DefineType := False;
                           Break;
                           end;
                      end
                 else begin
                      AddError( New( PMessageError, Create( 'ERROR: Can`t match type size ~' + TypeIdentifier + '~ .')));
                      DefineType := False;
                      Break;
                      end;
                 end
            else AddError( New( PMessageError, Create( 'ERROR: Duplicate identifier define ~' + TypeIdentifier + '~.')));
            end;
    end;

    function DefineOperation: Boolean;
    var OperationIdentifier: string;
    begin
         DefineOperation := True;
         DefinesFile.NextLexican;
         while (DefinesFile.Lexican = lexIdentifier)
         do begin
            OperationIdentifier := DefinesFile.LexicanString;
            if ( GetSymbolsAttributes( OperationIdentifier) = nil)
            then begin
                 AppendOperation( OperationIdentifier);
                 DefinesFile.NextLexican;
                 end
            else begin
                 AddError( New( PMessageError, Create( 'ERROR: Duplicate identifier define ~' + OperationIdentifier +'~.')));
                 DefineOperation := False;
                 Break;
                 end;
            end;
    end;

    function DefineExtraSymbol: Boolean;
    var SymbolIdentifier: string;
    begin
         DefineExtraSymbol := True;
         DefinesFile.NextLexican;
         while (DefinesFile.Lexican = lexIdentifier)
         do begin
            SymbolIdentifier := DefinesFile.LexicanString;
            if (GetSymbolsAttributes( SymbolIdentifier) = nil)
            then begin
                 AppendExtraSymbol( SymbolIdentifier);
                 DefinesFile.NextLexican;
                 end
            else begin
                 AddError( New( PMessageError, Create( 'ERROR: Duplicate identifier define ~' + SymbolIdentifier + '~.')));
                 DefineExtraSymbol := False;
                 Break;
                 end;
            end;
    end;

    function ReadTypeIdentifier: PTypeRecord;
    var Attributes: PSymbolAttributes;
    begin
         if DefinesFile.NextLexican = lexIdentifier
         then begin
              Attributes := GetSymbolsAttributes( DefinesFile.LexicanString);
              if (Attributes <> nil)
              then begin
                   if ( Attributes^.GetSymbolType = stType)
                   then ReadTypeIdentifier := PTypeRecord( Attributes)
                   else begin
                        AddError( New( PMessageError, Create( 'ERROR: Type name expected ~' + DefinesFile.LexicanString +
'~ .')));
                        ReadTypeIdentifier := nil;
                        end;
                   end
              else begin
                   AddError( New( PMessageError, Create('ERROR: Type name expected ~' + DefinesFile.LexicanString + '~ .')));
                   ReadTypeIdentifier := nil;
                   end
              end
         else begin
              AddError( New( PMessageError, Create( 'ERROR: Type name expected.')));
              ReadTypeIdentifier := nil;
              end;
    end;


    function DefineMacro: Boolean;
    var TypeRecord: PTypeRecord;
        Macro: PMacro;
        Rule: PRule;
        ParserSymbol: PParserSymbol;

        function ReadMacroBody: PMacro;
        var Macro: PMacro;
            LexicanAttribute: TLexicanAttribute;
        begin
             if DefinesFile.NextLexican = lexMacroBody
             then begin
                  if DefinesFile.GetLexicanAttribute( LexicanAttribute)
                  then begin
                       Macro := New(PMacro,Create( @Self));
                       if Macro^.Build( @DefinesDataBase.SymbolsTable, LexicanAttribute.Buffer, LexicanAttribute.BufferSize)
                       then ReadMacroBody := Macro
                       else begin
                            Macro^.Free;
                            ReadMacroBody := nil;
                            end;
                       end
                  else ReadMacroBody := nil;
                  end
             else begin
                  AddError( New( PMessageError, Create( 'ERROR: Macro body expected.')));
                  ReadMacroBody := nil;
                  end;
        end;

        function ReadExtraParserSymbol: PParserSymbol;
        var
            SymbolAttributes : PSymbolAttributes;
        begin
             ReadExtraParserSymbol := nil;
             if DefinesFile.NextLexican = lexIdentifier
             then begin
                  SymbolAttributes := GetSymbolsAttributes( DefinesFile.LexicanString);
                  if (SymbolAttributes <> nil)
                  then begin
                       if ( SymbolAttributes^.GetSymbolType = stExtraSymbol)
                       then begin
                            ReadExtraParserSymbol := PExtraSymbolRecord( SymbolAttributes)^.GetSymbol;
                            end
                       else AddError( New( PMessageError, Create( 'ERROR: Bad left side symbol, extra symbol expected ~' +
DefinesFile.LexicanString + '~.')));
                       end
                  else AddError( New( PMessageError, Create( 'ERROR: Not defined identifier ~' + DefinesFile.LexicanString +
'~.')));
                  end
             else AddError( New( PMessageError, Create( 'ERROR: Extra symbol identifier expected.')));
        end;

        function ReadParserSymbol: PParserSymbol;
        var TypeRecord: PTypeRecord;
            AttributeSymbol: PSymbolAttributes;
        begin
             ReadParserSymbol := nil;
             if DefinesFile.NextLexican = lexIdentifier
             then begin
                  if DefinesFile.LexicanString = GLOBAL_SYM
                  then begin
                       TypeRecord := ReadTypeIdentifier;
                       if ( TypeRecord <> nil)
                       then ReadParserSymbol := TypeRecord^.GetVariableSymbol;
                       end
                  else if DefinesFile.LexicanString = LOCAL_SYM
                  then begin
                       TypeRecord := ReadTypeIdentifier;
                       if ( TypeRecord <> nil)
                       then ReadParserSymbol := TypeRecord^.GetLocalSymbol;
                       end
                  else if DefinesFile.LexicanString = CONSTANT_SYM
                  then begin
                       TypeRecord := ReadTypeIdentifier;
                       if ( TypeRecord <> nil)
                       then ReadParserSymbol := TypeRecord^.GetConstantSymbol;
                       end
                  else if DefinesFile.LexicanString = PARAMETER_SYM
                  then begin
                       TypeRecord := ReadTypeIdentifier;
                       if ( TypeRecord <> nil)
                       then ReadParserSymbol := TypeRecord^.GetParameterSymbol;
                       end
                  else if DefinesFile.LexicanString = ID_SYM
                  then begin
                       ReadParserSymbol := DefinesDataBase.IDParserSymbol;
                       end
                  else begin
                       AttributeSymbol := GetSymbolsAttributes( DefinesFile.LexicanString);
                       if ( AttributeSymbol <> nil)
                       then begin
                            case AttributeSymbol^.GetSymbolType
                            of stOperation: ReadParserSymbol := POperationRecord( AttributeSymbol)^.GetSymbol;
                               stExtraSymbol: ReadParserSymbol := PExtraSymbolRecord( AttributeSymbol)^.GetSymbol;
                               else
                               AddError( New( PMessageError, Create( 'ERROR: Not alowed symbol used ~' +
DefinesFile.LexicanString + '~.')));
                               end
                            end
                       else AddError( New( PMessageError, Create( 'ERROR: Not defined symbol ~' + DefinesFile.LexicanString +
'~ .')));
                       end;
                  end;
        end;

    begin
         DefineMacro := False;
         if DefinesFile.NextLexican = lexIdentifier
         then begin
              if DefinesFile.LexicanString = PARAMETERINITMACRO_SYM
              then begin
                   if DefinesFile.NextLexican = lexIdentifier
                   then begin
                        if DefinesFile.LexicanString = CONSTANT_SYM
                        then begin
                             TypeRecord := ReadTypeIdentifier;
                             if ( TypeRecord <> nil)
                             then begin
                                  if ( TypeRecord^.GetConstantParameterInitMacro = nil)
                                  then begin
                                       Macro := ReadMacroBody;
                                       if (Macro <> nil)
                                       then begin
                                            TypeRecord^.SetConstantParameterInitMacro( Macro);
                                            AppendMacro( Macro);
                                            DefinesFile.NextLexican;
                                            DefineMacro := True;
                                            end;
                                       end
                                  else AddError( New( PMessageError, Create('ERROR: This macro defined previosly.')));
                                  end
                             end
                        else if DefinesFile.LexicanString = GLOBAL_SYM
                        then begin
                             TypeRecord := ReadTypeIdentifier;
                             if (TypeRecord <> nil)
                             then begin
                                  if (TypeRecord^.GetVaraiableParameterInitMacro = nil)
                                  then begin
                                       Macro := ReadMacroBody;
                                       if (Macro <> nil)
                                       then begin
                                            TypeRecord^.SetVaraiableParameterInitMacro( Macro);
                                            AppendMacro( Macro);
                                            DefinesFile.NextLexican;
                                            DefineMacro := True;
                                            end
                                       end
                                  else AddError( New( PMessageError, Create( 'ERROR: This macro defined previosly.')));
                                  end
                             end
                        else if DefinesFile.LexicanString = LOCAL_SYM
                        then begin
                             TypeRecord := ReadTypeIdentifier;
                             if ( TypeRecord <> nil)
                             then begin
                                  if ( TypeRecord^.GetLocalParameterInitMacro = nil)
                                  then begin
                                       Macro := ReadMacroBody;
                                       if (Macro <> nil)
                                       then begin
                                            TypeRecord^.SetLocalParameterInitMacro( Macro);
                                            AppendMacro( Macro);
                                            DefinesFile.NextLexican;
                                            DefineMacro := True;
                                            end
                                       end
                                  else AddError(  New( PMessageError, Create( 'ERROR: This macro defined previosly.')));
                                  end
                             end
                        else if DefinesFile.LexicanString = PARAMETER_SYM
                        then begin
                             TypeRecord := ReadTypeIdentifier;
                             if ( TypeRecord <> nil)
                             then begin
                                  if ( TypeRecord^.GetParameterParameterInitMacro = nil)
                                  then begin
                                       Macro := ReadMacroBody;
                                       if ( Macro <> nil)
                                       then begin
                                            TypeRecord^.SetParameterParameterInitMacro( Macro);
                                            AppendMacro( Macro);
                                            DefinesFile.NextLexican;
                                            DefineMacro := True;
                                            end
                                       end
                                  else AddError( New( PMessageError,Create( 'ERROR: This macro defined previosly.')));
                                  end
                             end
                        else AddError( New( PMessageError, Create( 'ERROR: (~' + CONSTANT_SYM + '~, ~' + GLOBAL_SYM + '~, ~' +
LOCAL_SYM + '~ or ~' + PARAMETER_SYM + '~) expected.')));
                        end
                   else AddError( New( PMessageError, Create( 'ERROR: Bad macro define.')));
                   end
              else if DefinesFile.LexicanString = SUBEXPRESIONMACRO_SYM
              then begin
                   if DefinesFile.NextLexican = lexMidArcLeft
                   then begin
                        Rule := New( PRule, Create);
                        ParserSymbol := ReadExtraParserSymbol;
                        if ( ParserSymbol <> nil)
                        then begin
                             Rule^.SetLeftSymbol( ParserSymbol);
                             if ( DefinesFile.NextLexican = lexTwoPoints)
                             then begin
                                  ParserSymbol := ReadParserSymbol;
                                  if ( ParserSymbol <> nil)
                                  then begin
                                       repeat
                                       Rule^.AppendRightSymbol( ParserSymbol);
                                       if ( DefinesFile.NextLexican = lexComa)
                                       then ParserSymbol := ReadParserSymbol
                                       else begin
                                            ParserSymbol := nil;
                                            if ( DefinesFile.Lexican = lexMidArcRight)
                                            then begin
                                                 Macro := ReadMacroBody;
                                                 if ( Macro <> nil)
                                                 then begin
                                                      Rule^.SetReduceInfo( Macro);
                                                      AppendRule( Rule);
                                                      AppendMacro( Macro);
                                                      DefinesFile.NextLexican;
                                                      DefineMacro := True;
                                                      end
                                                 else Rule^.Free;
                                                 end
                                            else begin
                                                 Rule^.Free;
                                                 AddError( New( PMessageError,Create( 'ERROR: ~]~ or ~,~ expected.')));
                                                 end;
                                            end
                                       until ParserSymbol = nil;
                                       end
                                  else Rule^.Free;
                                  end
                             else begin
                                  Rule^.Free;
                                  AddError( New( PMessageError, Create( 'ERROR: ~:~ expected.')));
                                  end;
                             end
                        else Rule^.Free;
                        end
                   else AddError( New( PMessageError, Create( 'ERROR: ~[~ expected.')));
                   end
              else if DefinesFile.LexicanString = FREERESULTMACRO_SYM
              then begin
                   TypeRecord := ReadTypeIdentifier;
                   if ( TypeRecord <> nil)
                   then begin
                        if ( TypeRecord^.GetResultFreeMacro = nil)
                        then begin
                             Macro := ReadMacroBody;
                             if ( Macro <> nil)
                             then begin
                                  TypeRecord^.SetResultFreeMacro( Macro);
                                  AppendMacro( Macro);
                                  DefinesFile.NextLexican;
                                  DefineMacro := True;
                                  end;
                             end
                        else AddError( New( PMessageError, Create( 'ERROR: This macro defined previosly.')));
                        end
                   end
              else if DefinesFile.LexicanString = BLOCKMACRO_SYM
              then begin
                   if DefinesFile.NextLexican = lexIdentifier
                   then begin
                        Identifier := DefinesFile.LexicanString;
                        Macro := ReadMacroBody;
                        if ( Macro <> nil)
                        then begin
                             AppendMacro( Macro);
                             if AppendBlock( Identifier, Macro)
                             then begin
                                  DefinesFile.NextLexican;
                                  DefineMacro := True;
                                  end;
                             end;
                        end
                   else AddError( New( PMessageError, Create( 'ERROR: Block name expected.')));
                   end
              else AddError( New( PMessageError, Create( 'ERROR: (~' + PARAMETERINITMACRO_SYM + '~, ~' + SUBEXPRESIONMACRO_SYM
+ '~, ~' + BLOCKMACRO_SYM + '~, ~' + FREERESULTMACRO_SYM + '~) expected.')));
              end
         else AddError( New( PMessageError, Create( 'ERROR: Bad macro define.')));
    end;

    function DefineMap:  Boolean;
    var SymbolAttributes: PSymbolAttributes;
        Macro: PMacro;
    begin
         DefineMap := True;
         if DefinesFile.NextLexican = lexIdentifier
         then begin
              if DefinesFile.LexicanString = PROCEDUREMAP_SYM
              then begin
                   while DefinesFile.NextLexican = lexIdentifier
                   do begin
                      if DefinesFile.LexicanString = CODE_SYM
                      then DefinesDataBase.Maps.ProcedureMap.Append( New( PMapItem, Create( miCode, nil)))
                      else begin
                           SymbolAttributes := GetSymbolsAttributes( DefinesFile.LexicanString);
                           if ( SymbolAttributes <> nil)
                           then begin
                                if ( SymbolAttributes^.GetSymbolType = stBlock)
                                then begin
                                     Macro := PBlockRecord( SymbolAttributes)^.GetBlockMacro;
                                     if (Macro <> nil)
                                     then DefinesDataBase.Maps.ProcedureMap.Append( New( PMapItem, Create( miMacro, Macro)))
                                     else begin
                                          AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro nor matched.')));
                                          DefineMap := False;
                                          Break;
                                          end;
                                     end
                                else begin
                                     AddError( New( PMessageError, Create('ERROR: Block name expected.')));
                                     DefineMap := False;
                                     Break;
                                     end;
                                end
                           else begin
                                AddError( New( PMessageError, Create( 'ERROR: Not defined symbol.')));
                                DefineMap := False;
                                Break;
                                end;
                           end;
                      end;
                   end
              else if DefinesFile.LexicanString = CALLMAP_SYM
              then begin
                   while DefinesFile.NextLexican = lexIdentifier
                   do begin
                      if DefinesFile.LexicanString = PARAMETERSINIT_SYM
                      then DefinesDataBase.Maps.ProcedureCallMap.Append( New( PMapItem, Create( miParamsInit, nil)))
                      else begin
                           SymbolAttributes := GetSymbolsAttributes( DefinesFile.LexicanString);
                           if ( SymbolAttributes <> nil)
                           then begin
                                if ( SymbolAttributes^.GetSymbolType = stBlock)
                                then begin
                                     Macro := PBlockRecord( SymbolAttributes)^.GetBlockMacro;
                                     if ( Macro <> nil)
                                     then DefinesDataBase.Maps.ProcedureCallMap.Append( New( PMapItem,
Create( miMacro, Macro)))
                                     else begin
                                          AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro nor matched.')));
                                          DefineMap := False;
                                          Break;
                                          end;
                                     end
                                else begin
                                     AddError( New( PMessageError, Create( 'ERROR: Block name expected.')));
                                     DefineMap := False;
                                     Break;
                                     end;
                                end
                           else begin
                                AddError( New( PMessageError, Create( 'ERROR: Not defined symbol.')));
                                DefineMap := False;
                                Break;
                                end;
                           end;
                      end;
                   end
              else if DefinesFile.LexicanString = MAINMAP_SYM
              then begin
                   while DefinesFile.NextLexican = lexIdentifier
                   do begin
                      if DefinesFile.LexicanString = CODE_SYM
                      then DefinesDataBase.Maps.MainMap.Append( New( PMapItem, Create( miCode, nil)))
                      else begin
                           SymbolAttributes := GetSymbolsAttributes(DefinesFile.LexicanString);
                           if ( SymbolAttributes <> nil)
                           then begin
                                if ( SymbolAttributes^.GetSymbolType = stBlock)
                                then begin
                                     Macro := PBlockRecord( SymbolAttributes)^.GetBlockMacro;
                                     if (Macro <> nil)
                                     then DefinesDataBase.Maps.MainMap.Append( New( PMapItem, Create( miMacro, Macro)))
                                     else begin
                                          AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro not matched.')));
                                          DefineMap := False;
                                          Break;
                                          end;
                                     end
                                else begin
                                     AddError( New( PMessageError, Create( 'ERROR: Block name expected.')));
                                     DefineMap := False;
                                     Break;
                                     end;
                                end
                           else begin
                                AddError( New( PMessageError, Create( 'ERROR: Not defined symbol.')));
                                DefineMap := False;
                                Break;
                                end;
                           end;
                      end;
                   end
              else if DefinesFile.LexicanString = GLOBALMAP_SYM
              then begin
                   while DefinesFile.NextLexican = lexIdentifier
                   do begin
                      if DefinesFile.LexicanString = CODE_SYM
                      then DefinesDataBase.Maps.GlobalMap.Append( New( PMapItem, Create( miCode, nil)))
                      else begin
                           SymbolAttributes := GetSymbolsAttributes( DefinesFile.LexicanString);
                           if ( SymbolAttributes <> nil)
                           then begin
                                if ( SymbolAttributes^.GetSymbolType = stBlock)
                                then begin
                                     Macro := PBlockRecord( SymbolAttributes)^.GetBlockMacro;
                                     if (Macro <> nil)
                                     then DefinesDataBase.Maps.GlobalMap.Append( New( PMapItem, Create( miMacro, Macro)))
                                     else begin
                                          AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro not matched.')));
                                          DefineMap := False;
                                          Break;
                                          end;
                                     end
                                else begin
                                     AddError( New( PMessageError, Create( 'ERROR: Block name expected.')));
                                     DefineMap := False;
                                     Break;
                                     end;
                                end
                           else begin
                                AddError( New( PMessageError, Create( 'ERROR: Not defined symbol.')));
                                DefineMap := False;
                                Break;
                                end;
                           end;
                      end;
                   end
              else AddError( New( PMessageError, Create( 'ERROR: Bad item name to define map for.')));
              end
         else AddError( New( PMessageError, Create( 'ERROR: Error map define.')));
    end;

var
   SymbolAttributes: PSymbolAttributes;
   Rule: PRule;
   ErrorCount: Word;
   I: Integer;
   Error: PMessageError;

   InputStream: PStream;

   MapItem: PMapItem;
   Found: Boolean;
begin
     InputStream := New( PDOSStream, Init( AFileName, stOpenRead));
     WriteLn;
     Write( 'Reading define file ... "');
     Write( AFileName);
     WriteLn( '"');

     ClearLocalInfo;
     ClearGlobalInfo;
     ClearSymbolsTable;
     ClearMocros;
     ClearGrammar;
     ClearParserSymbols;
     ClearError;

     AppendExtraSymbol( STATMENT_SYM);
{$IFDEF DEBUGSTATE}
     DefinesDataBase.IDParserSymbol := CreateParserSymbol('ID');
{$ELSE}
     DefinesDataBase.IDParserSymbol := CreateParserSymbol;
{$ENDIF}
     AppendVariable( 'GLOBAL_DATA_SIZE', New( PVarValueInfo, Create( @TranslationVars.GlobalDataSize)));
     AppendVariable( 'LOCAL_DATA_SIZE', New( PVarValueInfo, Create( @TranslationVars.LocalDataSize)));
     AppendVariable( 'PARAM_DATA_SIZE', New( PVarValueInfo, Create( @TranslationVars.ParametersDataSize)));
     AppendVariable( 'RETURN_DATA_SIZE', New( PVarValueInfo, Create( @TranslationVars.ReturnDataSize)));
     AppendVariable( 'PARAMS_BLOCK_SIZE', New( PVarValueInfo, Create( @TranslationVars.ParametersBlockSize)));
     AppendVariable( 'CALL_PARAM_COUNT', New( PVarValueInfo, Create( @TranslationVars.CallParametersCount)));
     AppendVariable( 'CALL_PARAM_OFFSET', New( PVarValueInfo, Create( @TranslationVars.CallParameterOffset)));
     AppendVariable( 'PROC_ID', New( PVarValueInfo, Create( @TranslationVars.ProcedureID)));

     AppendVariable( 'CALL_PARAM_NO', New( PVarValueInfo, Create(@TranslationVars.CallParameterNo)));
     AppendVariable( 'GLOBAL_ID', New( PVarValueInfo, Create( @TranslationVars.GlobalID)));
     AppendVariable( 'GLOBAL_OFFSET', New( PVarValueInfo, Create( @TranslationVars.GlobalOffset)));
     AppendVariable( 'LOCAL_ID', New( PVarValueInfo, Create( @TranslationVars.LocalId)));
     AppendVariable( 'LOCAL_OFFSET', New( PVarValueInfo, Create( @TranslationVars.LocalOffset)));
     AppendVariable( 'PARAM_ID', New( PVarValueInfo, Create( @TranslationVars.ParamId)));
     AppendVariable( 'PARAM_OFFSET', New( PVarValueInfo, Create( @TranslationVars.ParamOffset)));
     AppendVariable( 'CONST_VALUE',  New( PVarValueInfo, Create( @TranslationVars.ConstantValue)));
     AppendVariable( 'CALLED_PROC_ID', New( PVarValueInfo, Create( @TranslationVars.CalledProcedureID)));

     { Init the first rule in the grammar }
     { nil -> STATMENT }
     { Other rules will take the form like : STATEMENT -> ... }
     SymbolAttributes := GetSymbolsAttributes( STATMENT_SYM);
     if ( SymbolAttributes <> nil)
     then if SymbolAttributes^.GetSymbolType = stExtraSymbol
          then begin
               Rule := New( PRule, Create);
               Rule^.SetLeftSymbol( nil);
               Rule^.AppendRightSymbol( PExtraSymbolRecord( SymbolAttributes)^.GetSymbol);
               AppendRule( Rule);
               end;

     DefinesFile.Create( InputStream);
     DefinesFile.Reset;
     DefinesFile.NextLexican;
     while ( DefinesFile.Lexican = lexCommand)
     do begin
        if DefinesFile.LexicanString = TYPEDEF_CMD
        then begin
             if not DefineType
             then break;
             end
        else if DefinesFile.LexicanString = OPDEF_CMD
        then begin
             if not DefineOperation
             then break;
             end
        else if DefinesFile.LexicanString = SYMDEF_CMD
        then begin
             if not DefineExtraSymbol
             then break;
             end
        else if DefinesFile.LexicanString = MACRODEF_CMD
        then begin
             if not DefineMacro
             then break;
             end
        else if DefinesFile.LexicanString = MAPDEF_CMD
        then begin
             if not DefineMap
             then break;
             end
        else begin
             AddError( New( PMessageError, Create('ERROR: Bad command.')));
             break;
             end
        end;
     if ( AnyError)
     then begin
          WriteLn;
          WriteLn;
          ErrorCount := GetErrorsCount;
          for I := 1 to ErrorCount
          do begin
             Error := PMessageError( GetError(I));
             if ( Error <> nil)
             then WriteLn( Error^.GetMessage);
             end;
          WriteLn('  (line: ', DefinesFile.GetLineNo,'  col: ', DefinesFile.GetColNo, ')');
          end
     else begin
          Found := False;
          MapItem := DefinesDataBase.Maps.GlobalMap.GetFirst;
          while (( not Found) and ( MapItem <> nil))
          do begin
             if MapItem^.GetItemType = miCode
             then Found := True
             else MapItem := DefinesDataBase.Maps.GlobalMap.GetNext;
             end;
          if not Found
          then DefinesDataBase.Maps.GlobalMap.Append( New( PMapItem, Create( miCode,nil)));
          Found := False;
          MapItem := DefinesDataBase.Maps.MainMap.GetFirst;
          while (( not Found) and ( MapItem <> nil))
          do begin
             if MapItem^.GetItemType = miCode
             then Found := True
             else MapItem := DefinesDataBase.Maps.MainMap.GetNext;
             end;
          if not Found
          then DefinesDataBase.Maps.MainMap.Append( New( PMapItem, Create( miCode, nil)));
          Found := False;
          MapItem := DefinesDataBase.Maps.ProcedureMap.GetFirst;
          while (( not Found) and ( MapItem <> nil))
          do begin
             if MapItem^.GetItemType = miCode
             then Found := True
             else MapItem := DefinesDataBase.Maps.ProcedureMap.GetNext;
             end;

          if not Found
          then DefinesDataBase.Maps.ProcedureMap.Append( New( PMapItem, Create( miCode, nil)));

          WriteLn( 'Create parser table ...');
          Parser.BuildParser;
          end;
     DefinesFile.Destroy;
     WriteLn( 'Define file processings finished ...');
     if InputStream <> nil
     then Dispose( InputStream, Done);
end;

procedure TTranslator.TranslateFile( InputFileName: string; OutputFileName: string);
var
   InputFile: TFileSource;
   InputStream: PStream;
   OutputStream: PStream;

   function DefineGlobals: Boolean;
   var Attribute: PTypeRecord;
       LexAttrib: TLexicanAttribute;
       VarCount: Longint;
   begin
        DefineGlobals := True;
        InputFile.NextLexican;
        while ( InputFile.Lexican = lexIdentifier)
        do begin
           Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, True));
           if ( Attribute <> nil)
           then begin
                if InputFile.NextLexican = lexInteger
                then begin
                     InputFile.GetLexicanAttribute(LexAttrib);
                     VarCount := LexAttrib.IntegerValue;
                     InputFile.NextLexican;
                     end
                else VarCount := 1;
                AppendGlobalVar( New( PGlobalVarRecord, Create( VarCount * Attribute^.GetTypeSize)));
                end
           else begin
                DefineGlobals := False;
                Break;
                end;
           end;
   end;

   function ReadOperation: PParserSymbol;
   var Attribute: POperationRecord;
   begin
        ReadOperation := nil;
        InputFile.NextLexican;
        Attribute := POperationRecord( MatchSymbol( @InputFile, stOperation, True));
        if ( Attribute <> nil)
        then ReadOperation := POperationRecord( Attribute)^.GetSymbol
   end;

   function ReadVariable( var AVarRecord: PGlobalVarRecord): PParserSymbol;
   var Attribute: PTypeRecord;
       VriableId: Longint;
   begin
        ReadVariable := nil;
        InputFile.NextLexican;
        Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, True));
        if ( Attribute <> nil)
        then begin
             if ReadInteger( @InputFile, VriableId)
             then begin
                  AVarRecord := GetGlobalVar( VriableId);
                  if ( AVarRecord <> nil)
                  then ReadVariable := Attribute^.GetVariableSymbol
                  else AddError( New( PMessageError, Create( 'ERROR: Bad global variable ID.')));
                  end;
             end;
   end;

   function ReadLocal( var ALocalVarRecord: PLocalVarRecord): PParserSymbol;
   var Attribute: PTypeRecord;
       VriableId: Longint;
   begin
        ReadLocal := nil;
        InputFile.NextLexican;
        Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, True));
        if ( Attribute <> nil)
        then begin
             if ReadInteger( @InputFile, VriableId)
             then begin
                  ALocalVarRecord := GetLocalVar( VriableId);
                  if ( ALocalVarRecord <> nil)
                  then ReadLocal := Attribute^.GetLocalSymbol
                  else AddError( New( PMessageError, Create( 'ERROR: Bad local variable ID.')));
                  end;
             end;
   end;

   function ReadParam( var AParameterRecord: PParameterRecord): PParserSymbol;
   var Attribute: PTypeRecord;
       VriableId: Longint;
   begin
        ReadParam := nil;
        InputFile.NextLexican;
        Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, True));
        if ( Attribute <> nil)
        then begin
             if ReadInteger( @InputFile, VriableId)
             then begin
                  AParameterRecord := GetParameter(VriableId);
                  if ( AParameterRecord <> nil)
                  then ReadParam := Attribute^.GetParameterSymbol
                  else AddError( New( PMessageError, Create( 'ERROR: Bad local variable ID.')));
                  end;
             end;
   end;

   function ReadConstant( var AConstantValue: Longint): PParserSymbol;
   var Attribute: PTypeRecord;
   begin
        ReadConstant := nil;
        InputFile.NextLexican;
        Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, True));
        if ( Attribute <> nil)
        then if ReadInteger( @InputFile, AConstantValue)
             then begin
                  ReadConstant := Attribute^.GetConstantSymbol;
                  end;
   end;

   function TranslateParserBlock: Boolean;
   var ParserSymbol: PParserSymbol;
       GlobalVarRecord: PGlobalVarRecord;
       LocalVarRecord: PLocalVarRecord;
       ParameterRecord: PParameterRecord;
       CValue: Longint;

       MapItem: PMapItem;

       function ProcessResultFree: Boolean;
       var Macro: PMacro;
       begin
            if ( TranslationDataBase.CurrentResultType <> nil)
            then begin
                 Macro := TranslationDataBase.CurrentResultType^.GetResultFreeMacro;
                 if Macro <> nil
                 then Macro^.GenerateOutput( OutputStream,nil);
                 TranslationDataBase.CurrentResultType := nil;
                 end;
            ProcessResultFree := True;
       end;

       function SetCurrentResultType( ATypeRecord: PTypeRecord): Boolean;
       begin
            TranslationDataBase.CurrentResultType := ATypeRecord;
       end;

       function CallBuild: Boolean;
       var SymbolAttributes: PSymbolAttributes;
           Id: Longint;
           Value: Longint;
           LexAttrib: TLexicanAttribute;
           CallParameter: PCallParameter;
           Generic: PGeneric;
           Macro: PMacro;

           function PlaceParamsInit: Boolean;
           begin
                TranslationVars.CallParameterNo := 1;
                TranslationVars.CallParameterOffset := 0;
                while ( TranslationVars.CallParameterNo <= TranslationVars.CallParametersCount)
                do begin
                   CallParameter := GetCallParameter( TranslationVars.CallParameterNo);
                   if ( CallParameter <> nil)
                   then begin
                        SymbolAttributes := CallParameter^.GetTypeRecord;
                        if ( SymbolAttributes <> nil)
                        then begin
                             case CallParameter^.GetCallParamType
                             of cpConst: begin
                                         Macro := PTypeRecord( SymbolAttributes)^.GetConstantParameterInitMacro;
                                         TranslationVars.GlobalID := 0;
                                         TranslationVars.GlobalOffset := 0;
                                         TranslationVars.LocalOffset := 0;
                                         TranslationVars.LocalId := 0;
                                         TranslationVars.ParamOffset := 0;
                                         TranslationVars.ParamId := 0;
                                         TranslationVars.ConstantValue := CallParameter^.GetConstantValue;
                                         end;
                                cpGlobal: begin
                                          Macro := PTypeRecord( SymbolAttributes)^.GetVaraiableParameterInitMacro;
                                          TranslationVars.GlobalID := CallParameter^.GetGlobalId;
                                          Generic := GetGlobalVar( TranslationVars.GlobalID);
                                          if ( Generic <> nil)
                                          then begin
                                               TranslationVars.GlobalOffset := PGlobalVarRecord( Generic)^.GetVarOffset;
                                               TranslationVars.LocalOffset := 0;
                                               TranslationVars.LocalId := 0;
                                               TranslationVars.ParamOffset := 0;
                                               TranslationVars.ParamId := 0;
                                               TranslationVars.ConstantValue := 0;
                                               end
                                          else begin
                                               AddError( New( PMessageError, Create( 'ERROR: Bad global var ID.')));
                                               Break;
                                               end;
                                          end;
                                cpLocal: begin
                                         Macro := PTypeRecord( SymbolAttributes)^.GetLocalParameterInitMacro;
                                         TranslationVars.LocalId := CallParameter^.GetLocalId;
                                         Generic := GetGlobalVar( TranslationVars.LocalId);
                                         if ( Generic <> nil)
                                         then begin
                                              TranslationVars.LocalOffset := PLocalVarRecord( Generic)^.GetVarOffset;
                                              TranslationVars.GlobalID := 0;
                                              TranslationVars.GlobalOffset := 0;
                                              TranslationVars.ParamOffset := 0;
                                              TranslationVars.ParamId := 0;
                                              TranslationVars.ConstantValue := 0;
                                              end
                                         else begin
                                              AddError( New( PMessageError, Create( 'ERROR: Bad local var ID.')));
                                              Break;
                                              end;
                                         end;
                                cpParam: begin
                                         Macro := PTypeRecord( SymbolAttributes)^.GetParameterParameterInitMacro;
                                         TranslationVars.ParamId := CallParameter^.GetParamId;
                                         Generic := GetParameter( TranslationVars.ParamId);
                                         if ( Generic <> nil)
                                         then begin
                                              TranslationVars.ParamOffset := PParameterRecord( Generic)^.GetVarOffset;
                                              TranslationVars.GlobalID := 0;
                                              TranslationVars.GlobalOffset := 0;
                                              TranslationVars.LocalOffset := 0;
                                              TranslationVars.LocalId := 0;
                                              TranslationVars.ParamOffset := 0;
                                              TranslationVars.ConstantValue := 0;
                                              end
                                         else begin
                                              AddError( New( PMessageError, Create( 'ERROR: Bad parameter ID.')));
                                              Break;
                                              end;
                                         end;
                                else
                                    Macro := nil;
                                end;

                             if (Macro <> nil)
                             then Macro^.GenerateOutput( OutputStream, nil)
                             else begin
                                  AddError( New( PMessageError, Create( 'ERROR: Not defined macro.')));
                                  break;
                                  end;

                             TranslationVars.CallParameterOffset := TranslationVars.CallParameterOffset + PTypeRecord(
SymbolAttributes)^.GetTypeSize;
                             end
                        else begin
                             AddError( New( PMessageError, Create( 'ERROR: Internal error.')));
                             break;
                             end;
                        end;
                   TranslationVars.CallParameterNo := TranslationVars.CallParameterNo + 1;
                   end;
                {If not complete => there is an error}
                PlaceParamsInit := TranslationVars.CallParameterNo > TranslationVars.CallParametersCount;
           end;
       begin
            CallBuild := False;
            ClearCallInfo;
            { emit the macro that free the space in stack ocupied by result from last function }
            if ProcessResultFree
            then while ( InputFile.NextLexican = lexIdentifier)
                 do begin
                    if InputFile.LexicanString = GLOBAL_SYM
                    then begin
                         InputFile.NextLexican;
                         SymbolAttributes := PTypeRecord( MatchSymbol( @InputFile, stType, True));
                         if ( SymbolAttributes <> nil)
                         then begin
                              if ReadInteger( @InputFile, Id)
                              then AppendCallParameter( New( PCallParameter, CreateGlobal(
PTypeRecord( SymbolAttributes), Id)))
                              else Break;
                              end
                         else Break;
                         end
                    else if InputFile.LexicanString = LOCAL_SYM
                    then begin
                         InputFile.NextLexican;
                         SymbolAttributes := PTypeRecord( MatchSymbol( @InputFile, stType, True));
                         if ( SymbolAttributes <> nil)
                         then begin
                              if ReadInteger( @InputFile, Id)
                              then AppendCallParameter( New( PCallParameter, CreateLocal(PTypeRecord(SymbolAttributes), Id)))
                              else Break;
                              end
                         else Break;
                         end
                    else if InputFile.LexicanString = PARAMETER_SYM
                    then begin
                         InputFile.NextLexican;
                         SymbolAttributes := PTypeRecord( MatchSymbol( @InputFile, stType, True));
                         if ( SymbolAttributes <> nil)
                         then begin
                              if ReadInteger( @InputFile, Id)
                              then AppendCallParameter( New( PCallParameter, CreateParam( PTypeRecord( SymbolAttributes), Id)))
                              else Break;
                              end
                         else Break;
                         end
                    else if InputFile.LexicanString = CONSTANT_SYM
                    then begin
                         InputFile.NextLexican;
                         SymbolAttributes := PTypeRecord( MatchSymbol( @InputFile, stType, True));
                         if (SymbolAttributes <> nil)
                         then begin
                              if ReadInteger(@InputFile, Value)
                              then AppendCallParameter(New(PCallParameter, CreateConstant(
PTypeRecord( SymbolAttributes), Value)))
                              else Break;
                              end
                         else Break;
                         end
                    else AddError( New( PMessageError, Create( 'ERROR: ~' + LOCAL_SYM + '~, ~' + GLOBAL_SYM + '~, ~' +
PARAMETER_SYM+'~ or ~'+CONSTANT_SYM + '~ expected.')))
                    end;

            if not AnyError
            then begin
                 if ( InputFile.Lexican = lexCommand)
                 then begin
                      if InputFile.LexicanString = CALL_CMD
                      then begin
                           if InputFile.NextLexican = lexIdentifier
                           then begin
                                SetCurrentResultType( PTypeRecord( MatchSymbol( @InputFile, stType, False)));
                                InputFile.NextLexican;
                                end
                           else SetCurrentResultType( nil);

                           if InputFile.Lexican = lexInteger {The title of procedure or function}
                           then begin
                                InputFile.GetLexicanAttribute( LexAttrib);
                                TranslationVars.CalledProcedureID := LexAttrib.IntegerValue;
                                MapItem := DefinesDataBase.Maps.ProcedureCallMap.GetFirst;
                                while ( MapItem <> nil)
                                do begin
                                   case MapItem^.GetItemType of
                                   miMacro: begin
                                            Macro := MapItem^.GetMacro;
                                            if ( Macro <> nil)
                                            then Macro^.GenerateOutput( OutputStream, nil)
                                            else begin
                                                 AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro not matched.')));
                                                 Break;
                                                 end;
                                            end;
                                   miParamsInit: begin
                                                 if not PlaceParamsInit
                                                 then Break;
                                                 end;
                                   end;
                                   MapItem := DefinesDataBase.Maps.ProcedureCallMap.GetNext;
                                   end;
                                end
                           else AddError( New( PMessageError, Create( 'ERROR: Procedure ID expected.')))
                           end
                      else AddError( New( PMessageError, Create( 'ERROR: Bad command, ~' + CALL_CMD + '~ expected.')))
                      end
                 else AddError( New( PMessageError, Create( 'ERROR: ~' + CALL_CMD + '~ command expected.')))
                 end;
            CallBuild := not AnyError;
       end;
   begin
        if Parser.InitTranslation
        then begin
             TranslationDataBase.CurrentResultType := nil;
             while True
             do begin
                while ( InputFile.NextLexican = lexIdentifier)
                do begin
                   if InputFile.LexicanString = OPERATION_SYM
                   then begin
                        ParserSymbol := ReadOperation;
                        if ParserSymbol <> nil
                        then begin
                             if not Parser.TakeNextSymbol( ParserSymbol, nil)
                             then break;
                             end
                        else break;
                        end
                   else if InputFile.LexicanString = GLOBAL_SYM
                   then begin
                        ParserSymbol := ReadVariable( GlobalVarRecord);
                        if ParserSymbol <> nil
                        then begin
                             {Must init the symbol attributes and send it tp parser after}
                             if not Parser.TakeNextSymbol( ParserSymbol, New(PGlobalSymbolAttr, Create( GlobalVarRecord)))
                             then break;
                             end
                        else break;
                        end
                   else if InputFile.LexicanString = LOCAL_SYM
                   then begin
                        ParserSymbol := ReadLocal( LocalVarRecord);
                        if ParserSymbol <> nil
                        then begin
                             {Must init the symbol attributes and send it tp parser after}
                             if not Parser.TakeNextSymbol( ParserSymbol, New( PLocalSymbolAttr, Create( LocalVarRecord)))
                             then break;
                             end
                        else break;
                        end
                   else if InputFile.LexicanString = PARAMETER_SYM
                   then begin
                        {#####}
                        ParserSymbol := ReadParam( ParameterRecord);
                        if ParserSymbol <> nil
                        then begin
                             {Must init the symbol attributes and send it tp parser after}
                             {#####}
                             if not Parser.TakeNextSymbol( ParserSymbol, New( PParameterSymbolAttr, Create( ParameterRecord)))
                             then break;
                             end
                        else break;
                        end
                   else if InputFile.LexicanString = CONSTANT_SYM
                   then begin
                        ParserSymbol := ReadConstant( CValue);
                        if ParserSymbol <> nil
                        then begin
                             {Must init the symbol attributes and send it tp parser after}
                             if not Parser.TakeNextSymbol( ParserSymbol, New( PConstantSymbolAttr, Create( CValue)))
                             then break;
                             end
                        else break;
                        end
                   else if InputFile.LexicanString = ID_SYM
                   then begin
                        if ReadInteger( @InputFile, CValue)
                        then begin
                             ParserSymbol := DefinesDataBase.IDParserSymbol;
                             if ParserSymbol <> nil
                             then begin
                                  {Must init the symbol attributes and send it tp parser after}
                                  if not Parser.TakeNextSymbol( ParserSymbol,New(PIDSymbolAttr, Create( CValue)))
                                  then break;
                                  end
                             else break;
                             end
                        else break;
                        end
                   else begin
                        AddError( New( PMessageError, Create( 'ERROR: Bad identifier ~' + InputFile.LexicanString + '~.')));
                        Break;
                        end;
                   end;

                if (not AnyError)
                then Parser.TakeNextSymbol( nil, nil);

                if AnyError
                then Break;

                if ( InputFile.Lexican = lexCommand)
                then begin
                     if InputFile.LexicanString = PARAMPASS_CMD
                     then begin
                          if not CallBuild
                          then Break;
                          end
                     else if InputFile.LexicanString = FREERESULT_CMD
                     then begin
                          if not ProcessResultFree
                          then Break;
                          end
                     else break;
                     end;
                end;

             if (not AnyError)
             then ProcessResultFree;
             Parser.DoneTranslation;
             end;
        TranslateParserBlock := not AnyError;
   end;

   function DefineProcedure: Boolean;
   var Attribute: PSymbolAttributes;
       DefinedReturnType: Boolean;
       LexicanAttribute: TLexicanAttribute;
       Count: Longint;
       GoOut: Boolean;
       ProcedureCodeGenerated : Boolean;
       MapItem: PMapItem;
       Macro: PMacro;
       Complete: Boolean;
   begin
        DefineProcedure := False;
        DefinedReturnType := False;

        ClearLocalInfo;

        InputFile.NextLexican;
        Complete := False;

        if (InputFile.Lexican = lexInteger)
        then begin
             InputFile.GetLexicanAttribute( LexicanAttribute);
             TranslationVars.ProcedureID := LexicanAttribute.IntegerValue;
             InputFile.NextLexican;
             while ( InputFile.Lexican = lexCommand)
             do begin
                if InputFile.LexicanString = PARAMDEF_CMD
                then begin
                     GoOut := False;
                     InputFile.NextLexican;
                     repeat
                           if ( InputFile.Lexican <> lexCommand)
                           then begin
                                Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, False));
                                if ( Attribute <> nil)
                                then begin
                                     if InputFile.NextLexican = lexInteger
                                     then begin
                                          InputFile.GetLexicanAttribute( LexicanAttribute);
                                          Count := LexicanAttribute.IntegerValue;
                                          InputFile.NextLexican;
                                          end
                                     else begin
                                          Count := 1;
                                          end;
                                     AppendParameter( New( PParameterRecord, Create(Count * PTypeRecord(
Attribute)^.GetTypeSize)));
                                     end
                                else begin
                                     AddError( New( PMessageError, Create( 'ERROR: Type name expected or command.')));
                                     Break;
                                     end;
                                end
                           else GoOut := True;
                     until GoOut;
                     end
                else if InputFile.LexicanString = LOCALDEF_CMD
                then begin
                     InputFile.NextLexican;
                     GoOut := False;
                     repeat
                           if (InputFile.Lexican <> lexCommand)
                           then begin
                                Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, False));
                                if ( Attribute <> nil)
                                then begin
                                     if InputFile.NextLexican = lexInteger
                                     then begin
                                          InputFile.GetLexicanAttribute( LexicanAttribute);
                                          Count := LexicanAttribute.IntegerValue;
                                          InputFile.NextLexican;
                                          end
                                     else Count := 1;
                                     AppendLocalVar( New( PLocalVarRecord, Create( Count *
PTypeRecord( Attribute)^.GetTypeSize)));
                                     end
                                else begin
                                     AddError( New( PMessageError, Create( 'ERROR: Type name expected or command.')));
                                     Break;
                                     end;
                                end
                           else GoOut := True;
                     until GoOut;
                     end
                else if InputFile.LexicanString = RETURNDEF_CMD
                     then begin
                          {must defined once only . . .}
                          if not DefinedReturnType
                          then begin
                               DefinedReturnType := True;
                               InputFile.NextLexican;
                               Attribute := PTypeRecord( MatchSymbol( @InputFile, stType, True));
                               if ( Attribute <> nil)
                               then begin
                                    TranslationVars.ReturnDataSize := PTypeRecord( Attribute)^.GetTypeSize;
                                    InputFile.NextLexican;
                                    if ( InputFile.Lexican <> lexCommand)
                                    then begin
                                         AddError( New( PMessageError, Create( 'ERROR: Command expected.')));
                                         Break;
                                         end;
                                    end
                               else Break;
                               end
                          else begin
                               AddError( New( PMessageError, Create( 'ERROR: Return type has been defined.')));
                               Break;
                               end;
                          end
                     else if InputFile.LexicanString = BLOCKSTART_CMD
                          then begin
                               { must exit this loop and use parser and procedure map to generate the code . . .}
                               ProcedureCodeGenerated := False;
                               MapItem := DefinesDataBase.Maps.ProcedureMap.GetFirst;
                               while ( MapItem <> nil)
                               do begin
                                  case MapItem^.GetItemType of
                                  miMacro: begin
                                           Macro := MapItem^.GetMacro;
                                           if (Macro <> nil)
                                           then Macro^.GenerateOutput( OutputStream, nil)
                                           else begin
                                                AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro not matched.')));
                                                Break;
                                                end;
                                           end;
                                  miCode: begin
                                          {Must be once}
                                          if not ProcedureCodeGenerated
                                          then begin
                                               ProcedureCodeGenerated := True;
                                               if not TranslateParserBlock
                                               then Break;
                                               if InputFile.Lexican = lexCommand
                                               then begin
                                                    if InputFile.LexicanString <> BLOCKEND_CMD
                                                    then begin
                                                         AddError( New( PMessageError, Create('ERROR: Bad command ~' +
InputFile.LexicanString + '~.')));
                                                         Break;
                                                         end;
                                                    InputFile.NextLexican;
                                                    end
                                               else begin
                                                    AddError( New( PMessageError, Create('ERROR: ~' +
BLOCKEND_CMD + '~ command expected')));
                                                    Break;
                                                    end;
                                               end
                                          else begin
                                               AddError( New( PMessageError,
Create( 'ERROR: Can`t generate procedure code more than one time.')));
                                               Break;
                                               end;
                                          end;
                                  end;
                               MapItem := DefinesDataBase.Maps.ProcedureMap.GetNext;
                               end;
                     if ( MapItem = nil)
                     then DefineProcedure := True;
                     Break;
                     {End of procedure define operation}
                     end
                else begin
                     {Not one of above tested commands}
                     AddError( New( PMessageError, Create( 'ERROR: Not expected command.')));
                     Break;
                     end;
                end;
             TranslationVars.ProcedureID := 0;
             end
        else begin
             AddError( New( PMessageError, Create( 'ERROR: Procedure ID expected.')));
             end;
   end;

   function GenerateMainCode: Boolean;
   var ParserBlockResult: Boolean;
   begin
        GenerateMainCode := True;
        ClearLocalInfo;{#####}
        ParserBlockResult := TranslateParserBlock;
        if ParserBlockResult
        then begin
             if ( InputFile.Lexican = lexCommand)
             then begin
                  if InputFile.LexicanString = BLOCKEND_CMD
                  then InputFile.NextLexican
                  else begin
                       AddError( New( PMessageError, Create( 'ERROR: Bad command.')));
                       GenerateMainCode := False;
                       end;
                  end
             else begin
                  AddError( New( PMessageError, Create( 'ERROR: Command expected.')));
                  GenerateMainCode := False;
                  end;
             end
        else GenerateMainCode := False;
   end;

   function GenerateGlobalCode: Boolean;
   var MapItem: PMapItem;
       Macro: PMacro;
   begin
        GenerateGlobalCode := True;
        while ( InputFile.Lexican = lexCommand)
        do begin
           if ( InputFile.LexicanString = PROCDEF_CMD)
           then begin
                if not DefineProcedure
                then begin
                     GenerateGlobalCode := False;
                     break;
                     end;
                end
           else if ( InputFile.LexicanString = BLOCKSTART_CMD)
           then begin
                { must set ~TranslationDataBase.CurrentResultType~ to nil here to relase the result saved in stack }
                MapItem := DefinesDataBase.Maps.MainMap.GetFirst;
                while ( MapItem <> nil)
                do begin
                   case MapItem^.GetItemType of
                   miMacro: begin
                            Macro := MapItem^.GetMacro;
                            if ( Macro <> nil)
                            then Macro^.GenerateOutput( OutputStream, nil)
                            else begin
                                 AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro not matched.')));
                                 GenerateGlobalCode := False;
                                 Break;
                                 end;
                            end;
                   miCode: begin
                           if not GenerateMainCode
                           then begin
                                GenerateGlobalCode := False;
                                Break;
                                end;
                           end;
                   end;
                   MapItem := DefinesDataBase.Maps.MainMap.GetNext;
                   end;
                end
           else begin
                AddError( New( PMessageError, Create( 'ERROR: Bad command ~' + InputFile.LexicanString + '~.')));
                GenerateGlobalCode := False;
                break;
                end;
           end;
   end;

   function Translate: Boolean;
   var MapItem: PMapItem;
       Macro: PMacro;
   begin
        Translate := True;
        InputFile.NextLexican;
        if ( InputFile.LexicanString = GLOBDEF_CMD)
        then DefineGlobals;
        MapItem := DefinesDataBase.Maps.GlobalMap.GetFirst;
        while ( MapItem <> nil)
        do begin
           case MapItem^.GetItemType of
           miMacro: begin
                    Macro := MapItem^.GetMacro;
                    if ( Macro <> nil)
                    then Macro^.GenerateOutput( OutputStream,nil)
                    else begin
                         AddError( New( PMessageError, Create( 'INTERNAL ERROR: Macro not matched.')));
                         Translate := False;
                         Break;
                         end;
                    end;
           miCode: begin
                   if not GenerateGlobalCode
                   then begin
                        Translate := False;
                        Break;
                        end;
                   end;
           end;
           MapItem := DefinesDataBase.Maps.GlobalMap.GetNext;
           end;
   end;


var
   ErrorCount: Word;
   I: Integer;
   Error: PMessageError;
begin
     if not AnyError
     then begin
          InputStream := New( PDOSStream, Init( InputFileName, stOpenRead));
          OutputStream := New( PDOSStream, Init( OutputFileName, stCreate));
          Parser.SetOutputStream( OutputStream);

          Write( 'Translation ... "');
          Write( InputFileName);
          Write( '" -> "');
          Write( OutputFileName);
          WriteLn( '"');
          ClearCallInfo;
          ClearLocalInfo;
          ClearGlobalInfo;
          ClearError;
          InputFile.Create( InputStream);
          Translate;
          if not AnyError
          then if ( InputFile.Lexican <> lexNone)
               then AddError( New( PMessageError, Create( 'ERROR: End of file expected.')));
          if ( AnyError)
          then begin
               WriteLn;
               ErrorCount := GetErrorsCount;
               for I := 1 to ErrorCount
               do begin
                  Error := PMessageError( GetError( I));
                  if ( Error <> nil)
                  then begin
                       WriteLn( Error^.GetMessage);
                       end;
                  end;
               WriteLn('  (line: ', InputFile.GetLineNo, '  col: ', InputFile.GetColNo, ')');
               end;
          InputFile.Destroy;
          WriteLn( 'Translation finished ...');
          if ( InputStream <> nil)
          then Dispose( InputStream, Done);
          if ( OutputStream <> nil)
          then Dispose( OutputStream, Done);
          Parser.SetOutputStream( nil);
          end
     else WriteLn('There is an error, no translation ocured ...')
end;

{$IFDEF DEBUGSTATE}
procedure TTranslator.Debug;
var TempSymbol: PParserSymbol;
    TempMacro: PMacro;
    I,J: Longint;
    TempRule: PRule;
begin
     WriteLn( DebugOutput);
     TempSymbol := PParserSymbol( DefinesDataBase.ParserSymbols.GetFirst);
     while ( TempSymbol <> nil)
     do begin
        WriteLn( DebugOutput, TempSymbol^.GetID, '.', TempSymbol^.GetTitle);
        TempSymbol := PParserSymbol( DefinesDataBase.ParserSymbols.GetNext);
        end;
     TempMacro := PMacro( DefinesDataBase.Macros.GetFirst);
     while ( TempMacro <> nil)
     do begin
        WriteLn( DebugOutput);
        WriteLn( DebugOutput, 'Macro :');
        TempMacro^.Display;
        TempMacro := PMacro( DefinesDataBase.Macros.GetNext);
        end;
     TempRule := DefinesDataBase.ParserGrammar.GetFirstRule;
     while ( TempRule <> nil)
     do begin
        WriteLn( DebugOutput);
        Write( DebugOutput, 'Rule : ');
        TempSymbol := TempRule^.GetLeftSymbol;
        if TempSymbol <> nil
        then Write( DebugOutput, TempSymbol^.GetTitle,' -> ')
        else Write( DebugOutput, 'NIL ->');
        J := TempRule^.GetRightSideSize;
        if (J > 1)
        then for I := 1 to J
             do begin
                TempSymbol := TempRule^.GetRightSymbol( I);
                if TempSymbol <> nil
                then Write( DebugOutput, TempSymbol^.GetTitle, ' ')
                else Write(DebugOutput,'NIL ');
                end;
        TempMacro := PMacro( TempRule^.GetReduceInfo);
        if ( TempMacro <> nil)
        then begin
             WriteLn( DebugOutput);
             TempMacro^.Display;
             end
        else begin
             WriteLn( DebugOutput);
             WriteLn( DebugOutput,'NO MACRO FOR THIS RULE');
             end;
        TempRule := DefinesDataBase.ParserGrammar.GetNextRule;
        end;
end;
{$ENDIF}

procedure TTranslator.ClearError;
begin
end;


constructor TVarValueInfo.Create( AVar: PLongint);
begin
     inherited Create;
     TheVar := AVar;
end;

function TVarValueInfo.GetValue: Longint;
begin
     if ( TheVar <> nil)
     then GetValue := TheVar^
     else GetValue := 0;
end;

procedure TVarValueInfo.SetVar( AVar: PLongint);
begin
     TheVar := AVar;
end;

var Generator:TTranslator;
    I: Integer;
    TestFile: TDosStream;
    ErrorOcured: Boolean;
begin
{$IFDEF DEBUGSTATE}
     Assign( DebugOutput, 'DEBUGOUT.TXT');
     Rewrite( DebugOutput);
     WriteLn( DebugOutput, 'Memory available before processing :', MemAvail);
     WriteLn( DebugOutput);
{$ENDIF}
     if (ParamCount = 3)
     then begin
          ErrorOcured := False;
          TestFile.Init(ParamStr(1),stOpenRead);
          if (TestFile.ErrorInfo <> stOk)
          then begin
               Writeln( 'ERROR: Bad defination file name ~' + ParamStr( 1) + '~ . . .');
               ErrorOcured := True;
               end;
          TestFile.Done;
          if not ErrorOcured
          then begin
               TestFile.Init( ParamStr(2), stOpenRead);
               if ( TestFile.ErrorInfo <> stOk)
               then begin
                    Writeln( 'ERROR: Bad source file name ~' + ParamStr( 2) + '~ . . .');
                    ErrorOcured := True;
                    end;
               TestFile.Done;
               end;

          if not ErrorOcured
          then begin
               Generator.Create;
               Generator.ReadDefinesFile( ParamStr( 1));
{$IFDEF DEBUGSTATE}
               Generator.Debug;
{$ENDIF}
               Generator.TranslateFile( ParamStr( 2), ParamStr( 3));
               Generator.Destroy;
               end;
          end
     else begin
          WriteLn( 'Bad parameters . . .');
          WriteLn( 'Use: TRANSLATE <Defines file name> <Source file name> <Output file name>');
          end;

{$IFDEF DEBUGSTATE}
     WriteLn( DebugOutput);
     WriteLn( DebugOutput, 'Memory available after processing :', MemAvail);
     Close( DebugOutput);
{$ENDIF}
end.