{*************************************************}
{*                                               *}
{*   SymbolsTable unit                           *}
{*                                               *}
{*************************************************}

unit SymbolsTable;

interface

uses Generics;

type
    PTableItem = ^TTableItem;
    TTableItem = record
        Attributes : PGeneric;
        Next       : PTableItem;
        Identifier : string;{ Must be last field in this structure}
        { The  ~Identifier~ filed size is variable according to the, itentifier length ... }
        end;

    PItemsList = ^TItemsList;
    TItemsList = object( TGeneric)
    private
        First : PTableItem;
    public
        constructor Create;
        destructor Destroy; virtual;
        procedure Clear;
        procedure Insert( AIdentifier: string; AAttributes: PGeneric);
        function Find( AIdentifier: string): PGeneric;
    end;

    PHashTable = ^THashTable;
    THashTable = array[0..0] of PItemsList;

    PSymbolsTable = ^TSymbolsTable;
    TSymbolsTable = Object( TGeneric)
    private
           HashTableSize : Word;
           HashTable     : PHashTable;
    public
        constructor Create( AHashTableSize: Word);
        destructor Destroy; virtual;
        procedure Clear;
        procedure Insert( AIdentifier: string; AAttributes: PGeneric);
        function Find( AIdentifier: string): PGeneric;

    end;

implementation

function AllocateTableItem( AIdentifier: string): PTableItem;
var Temp : PTableItem;
begin
     if ( Length( AIdentifier) > 0)
     then begin
          GetMem( Temp, SizeOf( TTableItem) - 255 + Length( AIdentifier));
          Temp^.Identifier := AIdentifier;
          Temp^.Attributes := nil; { Will be filled by the caller ....}
          Temp^.Next := nil; { Will be filled by the caller ....}
          AllocateTableItem := Temp;
          end
     else AllocateTableItem := Nil;
end;

procedure FreeTableItem( AItem: PTableItem);
begin
     if (AItem <> nil)
     then begin
          if ( AItem^.Attributes <> nil)
          then AItem^.Attributes^.Free;
          FreeMem( AItem, SizeOf( TTableItem) - 255 + Length( AItem^.Identifier));
          end;
end;


constructor TItemsList.Create;
begin
     inherited Create;
     First := nil;
end;

destructor TItemsList.Destroy;
var Temp : PTableItem;
begin
     Temp := First;
     while ( Temp <> nil)
     do begin
        First := Temp^.Next;
        FreeTableItem( Temp);
        Temp := First;
        end;
     inherited Destroy;
end;

procedure TItemsList.Clear;
var Temp : PTableItem;
begin
     Temp := First;
     while ( Temp <> nil)
     do begin
        First := Temp^.Next;
        FreeTableItem( Temp);
        Temp := First;
        end;
     First := nil;
end;

procedure TItemsList.Insert( AIdentifier: string; AAttributes: PGeneric);
var Temp : PTableItem;
begin
     Temp := AllocateTableItem( AIdentifier);
     if (Temp <> nil)
     then begin
          Temp^.Next := First;
          Temp^.Attributes := AAttributes;
          First := Temp;
          end
end;

function TItemsList.Find( AIdentifier: string): PGeneric;
var Temp : PTableItem;
begin
     Find := nil;
     Temp := First;
     while ( Temp <> nil)
     do if ( AIdentifier = Temp^.Identifier)
        then begin
             Find := Temp^.Attributes;
             break;
             end
        else Temp := Temp^.Next;
end;


constructor TSymbolsTable.Create( AHashTableSize: Word);
var I : Word;
begin
     inherited Create;
     if ( AHashTableSize > 0)
     then begin
          HashTableSize := AHashTableSize;
          GetMem( HashTable, SizeOf( PItemsList) * HashTableSize);
          for I := 0 to HashTableSize - 1
          do HashTable^[I] := new( PItemsList, Create);
          end
     else begin
          HashTableSize := 0;
          HashTable := nil;
          RunError(200);
          end;
end;

destructor TSymbolsTable.Destroy;
var I : Word;
begin
     if ( HashTableSize > 0)
     then begin
          for I := 0 to HashTableSize - 1
          do if ( HashTable^[I] <> nil)
             then HashTable^[I]^.Free;
          FreeMem( HashTable, SizeOf( PItemsList) * HashTableSize);
          end;
     inherited Destroy;
end;

procedure TSymbolsTable.Clear;
var Counter : Word;
begin
     if ( HashTableSize > 0)
     then begin
          for Counter := 0 to HashTableSize - 1
          do if ( HashTable^[Counter] <> nil)
             then HashTable^[Counter]^.Clear;
          end;
end;

procedure TSymbolsTable.Insert( AIdentifier: string; AAttributes: PGeneric);
var IdentifierLength : Byte;
    Counter          : Byte;
    HValue           : Word;
begin
     if ( AAttributes <> nil)
     then begin
          IdentifierLength := Length( AIdentifier);
          if ( IdentifierLength > 0)
          then begin
               HValue := 0;
               for Counter := 1 to IdentifierLength
               do HValue := HValue + Ord( AIdentifier[ Counter]);
               HValue := ( HValue mod HashTableSize);
               HashTable^[ HValue]^.Insert( AIdentifier, AAttributes);
               end;
          end;
end;

function TSymbolsTable.Find( AIdentifier: string): PGeneric;
var IdentifierLength : Byte;
    Counter          : Byte;
    HValue           : Word;
begin
     IdentifierLength := Length( AIdentifier);
     if ( IdentifierLength > 0)
     then begin
          HValue := 0;
          for Counter := 1 to IdentifierLength
          do HValue := HValue + Ord( AIdentifier[ Counter]);
          HValue := ( HValue mod HashTableSize);
          Find := HashTable^[ HValue]^.Find( AIdentifier);
          end
     else Find := nil;
end;

end.
