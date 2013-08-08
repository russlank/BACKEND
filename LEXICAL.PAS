{*************************************************}
{*                                               *}
{*   Lexical unit                                *}
{*                                               *}
{*************************************************}

unit Lexical;

interface

uses Generics, Objects;

const
   BUFFERSIZE = 1024;
   NUMSTATES = 33;
   FILEBUFFERSIZE = 1024;

type
    TLexican = ( lexNone,
                 lexError,
                 lexIdentifier,         {any word}
                 lexInteger,            {123}
                 lexFloat,              {0.0}
                 lexOperation,          {+ - * / % ^}
                 lexParamInd,           {@}
                 lexComa,               {,}
                 lexPComa,              {;}
                 lexTwoPoints,          {:}
                 lexDPoint,             {.}
                 lexArcLeft,            {(}
                 lexArcRight,           {)}
                 lexMidArcLeft,         {[}
                 lexMidArcRight,        {]}
                 lexCommand,            {#CommandIdentifier}
                 lexMacroBody,          (* { .... } *)
                 lexString);            {" ... "}

    TOperation = ( opPluss, opMinus, opMul, opDiv, opMod, opPower, opSignalPos, opSignalNeg);

    TLexicanAttribute = record
        case Integer
        of 0: ( );
           1: ( IntegerValue: LongInt);
           2: ( FloatValue: Real);
           3: ( Buffer: PChar; BufferSize: Word);
           4: ( Operation: TOperation);
        end;

    PSource = ^TSource;
    TSource = object(TGeneric)
    private
        CurrentState: Word;
        CurrentLexicanString: string;
        CurrentLexican: TLexican;
        CurrentLexicanAttr: TLexicanAttribute;
        Buffer: PChar;
        BufferCursor : PChar;
        BufferUsed: Word;
    public
        constructor Create;
        destructor Destroy; virtual;
        procedure Reset; virtual;
        procedure MoveForward; virtual;
        function GetChar: Char; virtual;
        function NextLexican: TLexican; virtual;
        function Lexican: TLexican; virtual;
        function LexicanString: string; virtual;
        function GetLexicanAttribute( var AAttr: TLexicanAttribute): Boolean; virtual;
    end;

    PFileSource = ^TFileSource;
    TFileSource = object( TSource)
    private
        SourceStream: PStream;
        FileBuffer: array[ 1..FILEBUFFERSIZE] of Char;
        FileBufferUsed: Word;
        FileBufferCursor: Word;
        LineNo: Longint;
        ColNo: Longint;
    public
        constructor Create( ASourceStream: PStream);
        destructor Destroy; virtual;
        procedure Reset; virtual;
        procedure MoveForward; virtual;
        function GetChar: Char; virtual;
        function GetLineNo: Longint;
        function GetColNo: Longint;
    end;

    PStringSource = ^TStringSource;
    TStringSource = object(TSource)
    private
           Str: string;
           Cursor: Word;
    public
        constructor Create(AStr: string);
        destructor Destroy; virtual;
        procedure Reset; virtual;
        procedure MoveForward; virtual;
        function GetChar: Char; virtual;
        function GetCursorPos: Longint;
    end;

implementation

type
   TCharacter = ( cChar,
                  cSeparator,
                  cDigit,
                  cAlpha,
                  cE,
                  cDPoint,
                  cComa,
                  cPComa,
                  cTwoPoints,
                  cLeftArc,
                  cRightArc,
                  cLeftMArc,
                  cRightMArc,
                  cLeftBArc,
                  cRightBArc,
                  cPluss,
                  cMinus,
                  cStar,
                  cDiv,
                  cPercent,
                  cPower,
                  cNet,
                  cParamInd,
                  cStrTip,
                  cEOF
                  );

   TCharType = Byte;

   TCharRec = record
     T: TCharacter;
     end;

   TCharsArray = array[char] of TCharRec;

   TWhat = Byte;

   TStateTableItem = record
        NextState: Word;
        Action: ( actAccept, actSkip, actAppend, actAppendToBuffer, actError, actStop);
        end;

   TStateTable = array[ TCharacter] of TStateTableItem;

   TStateRecord = record
     What: TLexican;
     Attribute: TLexicanAttribute;
     Table: TStateTable;
     end;

   TStates = array [ 1..NUMSTATES] of TStateRecord;

const
   {State = 1}
   States : TStates = (
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actError),
   { cSeparator }(NextState: 1;  Action: actSkip),
   { cDigit     }(NextState: 23;  Action: actAppend),
   { cAlpha     }(NextState: 22;  Action: actAppend),
   { cE         }(NextState: 22;  Action: actAppend),
   { cDPoint    }(NextState: 6;  Action: actAppend),
   { cComa      }(NextState: 3;  Action: actAppend),
   { cPComa     }(NextState: 4;  Action: actAppend),
   { cTwoPoints }(NextState: 5;  Action: actAppend),
   { cLeftArc   }(NextState: 12;  Action: actAppend),
   { cRightArc  }(NextState: 13;  Action: actAppend),
   { cLeftMArc  }(NextState: 10;  Action: actAppend),
   { cRightMArc }(NextState: 11;  Action: actAppend),
   { cLeftBArc  }(NextState: 7;  Action: actAppend),
   { cRightBArc }(NextState: 1;  Action: actError),
   { cPluss     }(NextState: 8;  Action: actAppend),
   { cMinus     }(NextState: 9;  Action: actAppend),
   { cStar      }(NextState: 1;  Action: actError),
   { cDiv       }(NextState: 1;  Action: actError),
   { cPercent   }(NextState: 1;  Action: actError),
   { cPower     }(NextState: 1;  Action: actError),
   { cNet       }(NextState: 20;  Action: actAppend),
   { cParamInd  }(NextState: 31;  Action: actAppend),
   { cStrTip    }(NextState: 32;  Action: actAppend),
   { cEOF       }(NextState: 1;  Action: actStop))
                ),

   {State = 2}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actError),
   { cSeparator }(NextState: 2;  Action: actSkip),
   { cDigit     }(NextState: 23;  Action: actAppend),
   { cAlpha     }(NextState: 22;  Action: actAppend),
   { cE         }(NextState: 22;  Action: actAppend),
   { cDPoint    }(NextState: 6;  Action: actAppend),
   { cComa      }(NextState: 3;  Action: actAppend),
   { cPComa     }(NextState: 4;  Action: actAppend),
   { cTwoPoints }(NextState: 5;  Action: actAppend),
   { cLeftArc   }(NextState: 12;  Action: actAppend),
   { cRightArc  }(NextState: 13;  Action: actAppend),
   { cLeftMArc  }(NextState: 10;  Action: actAppend),
   { cRightMArc }(NextState: 11;  Action: actAppend),
   { cLeftBArc  }(NextState: 7;  Action: actAppend),
   { cRightBArc }(NextState: 1;  Action: actError),
   { cPluss     }(NextState: 14;  Action: actAppend),
   { cMinus     }(NextState: 15;  Action: actAppend),
   { cStar      }(NextState: 16;  Action: actAppend),
   { cDiv       }(NextState: 17;  Action: actAppend),
   { cPercent   }(NextState: 19;  Action: actAppend),
   { cPower     }(NextState: 18;  Action: actAppend),
   { cNet       }(NextState: 20;  Action: actAppend),
   { cParamInd  }(NextState: 31;  Action: actAppend),
   { cStrTip    }(NextState: 32;  Action: actAppend),
   { cEOF       }(NextState: 1;  Action: actStop))
                ),

   {State = 3}
        ( What : lexComa;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 4}
        ( What : lexPComa;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 5}
        ( What : lexTwoPoints;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 6}
        ( What : lexDPoint;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 7}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 7;  Action: actAppendToBuffer),
   { cSeparator }(NextState: 7;  Action: actAppendToBuffer),
   { cDigit     }(NextState: 7;  Action: actAppendToBuffer),
   { cAlpha     }(NextState: 7;  Action: actAppendToBuffer),
   { cE         }(NextState: 7;  Action: actAppendToBuffer),
   { cDPoint    }(NextState: 7;  Action: actAppendToBuffer),
   { cComa      }(NextState: 7;  Action: actAppendToBuffer),
   { cPComa     }(NextState: 7;  Action: actAppendToBuffer),
   { cTwoPoints }(NextState: 7;  Action: actAppendToBuffer),
   { cLeftArc   }(NextState: 7;  Action: actAppendToBuffer),
   { cRightArc  }(NextState: 7;  Action: actAppendToBuffer),
   { cLeftMArc  }(NextState: 7;  Action: actAppendToBuffer),
   { cRightMArc }(NextState: 7;  Action: actAppendToBuffer),
   { cLeftBArc  }(NextState: 7;  Action: actAppendToBuffer),
   { cRightBArc }(NextState: 29;  Action: actAppend),
   { cPluss     }(NextState: 7;  Action: actAppendToBuffer),
   { cMinus     }(NextState: 7;  Action: actAppendToBuffer),
   { cStar      }(NextState: 7;  Action: actAppendToBuffer),
   { cDiv       }(NextState: 7;  Action: actAppendToBuffer),
   { cPercent   }(NextState: 7;  Action: actAppendToBuffer),
   { cPower     }(NextState: 7;  Action: actAppendToBuffer),
   { cNet       }(NextState: 7;  Action: actAppendToBuffer),
   { cParamInd  }(NextState: 7;  Action: actAppendToBuffer),
   { cStrTip    }(NextState: 7;  Action: actAppendToBuffer),
   { cEOF       }(NextState: 1;  Action: actError))
                ),

   {State = 8}
        ( What : lexOperation;
          Attribute : (Operation: opSignalPos);
          Table : (
   { cChar      }(NextState: 30;  Action: actAccept),
   { cSeparator }(NextState: 30;  Action: actAccept),
   { cDigit     }(NextState: 30;  Action: actAccept),
   { cAlpha     }(NextState: 30;  Action: actAccept),
   { cE         }(NextState: 30;  Action: actAccept),
   { cDPoint    }(NextState: 30;  Action: actAccept),
   { cComa      }(NextState: 30;  Action: actAccept),
   { cPComa     }(NextState: 30;  Action: actAccept),
   { cTwoPoints }(NextState: 30;  Action: actAccept),
   { cLeftArc   }(NextState: 30;  Action: actAccept),
   { cRightArc  }(NextState: 30;  Action: actAccept),
   { cLeftMArc  }(NextState: 30;  Action: actAccept),
   { cRightMArc }(NextState: 30;  Action: actAccept),
   { cLeftBArc  }(NextState: 30;  Action: actAccept),
   { cRightBArc }(NextState: 30;  Action: actAccept),
   { cPluss     }(NextState: 30;  Action: actAccept),
   { cMinus     }(NextState: 30;  Action: actAccept),
   { cStar      }(NextState: 30;  Action: actAccept),
   { cDiv       }(NextState: 30;  Action: actAccept),
   { cPercent   }(NextState: 30;  Action: actAccept),
   { cPower     }(NextState: 30;  Action: actAccept),
   { cNet       }(NextState: 30;  Action: actAccept),
   { cParamInd  }(NextState: 30;  Action: actAccept),
   { cStrTip    }(NextState: 30;  Action: actAccept),
   { cEOF       }(NextState: 30;  Action: actAccept))
                ),

   {State = 9}
        ( What : lexOperation;
          Attribute : (Operation: opSignalNeg);
          Table : (
   { cChar      }(NextState: 30;  Action: actAccept),
   { cSeparator }(NextState: 30;  Action: actAccept),
   { cDigit     }(NextState: 30;  Action: actAccept),
   { cAlpha     }(NextState: 30;  Action: actAccept),
   { cE         }(NextState: 30;  Action: actAccept),
   { cDPoint    }(NextState: 30;  Action: actAccept),
   { cComa      }(NextState: 30;  Action: actAccept),
   { cPComa     }(NextState: 30;  Action: actAccept),
   { cTwoPoints }(NextState: 30;  Action: actAccept),
   { cLeftArc   }(NextState: 30;  Action: actAccept),
   { cRightArc  }(NextState: 30;  Action: actAccept),
   { cLeftMArc  }(NextState: 30;  Action: actAccept),
   { cRightMArc }(NextState: 30;  Action: actAccept),
   { cLeftBArc  }(NextState: 30;  Action: actAccept),
   { cRightBArc }(NextState: 30;  Action: actAccept),
   { cPluss     }(NextState: 30;  Action: actAccept),
   { cMinus     }(NextState: 30;  Action: actAccept),
   { cStar      }(NextState: 30;  Action: actAccept),
   { cDiv       }(NextState: 30;  Action: actAccept),
   { cPercent   }(NextState: 30;  Action: actAccept),
   { cPower     }(NextState: 30;  Action: actAccept),
   { cNet       }(NextState: 30;  Action: actAccept),
   { cParamInd  }(NextState: 30;  Action: actAccept),
   { cStrTip    }(NextState: 30;  Action: actAccept),
   { cEOF       }(NextState: 30;  Action: actAccept))
                ),

   {State = 10}
        ( What : lexMidArcLeft;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 11}
        ( What : lexMidArcRight;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 12}
        ( What : lexArcLeft;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 13}
        ( What : lexArcRight;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 2;  Action: actAccept),
   { cSeparator }(NextState: 2;  Action: actAccept),
   { cDigit     }(NextState: 2;  Action: actAccept),
   { cAlpha     }(NextState: 2;  Action: actAccept),
   { cE         }(NextState: 2;  Action: actAccept),
   { cDPoint    }(NextState: 2;  Action: actAccept),
   { cComa      }(NextState: 2;  Action: actAccept),
   { cPComa     }(NextState: 2;  Action: actAccept),
   { cTwoPoints }(NextState: 2;  Action: actAccept),
   { cLeftArc   }(NextState: 2;  Action: actAccept),
   { cRightArc  }(NextState: 2;  Action: actAccept),
   { cLeftMArc  }(NextState: 2;  Action: actAccept),
   { cRightMArc }(NextState: 2;  Action: actAccept),
   { cLeftBArc  }(NextState: 2;  Action: actAccept),
   { cRightBArc }(NextState: 2;  Action: actAccept),
   { cPluss     }(NextState: 2;  Action: actAccept),
   { cMinus     }(NextState: 2;  Action: actAccept),
   { cStar      }(NextState: 2;  Action: actAccept),
   { cDiv       }(NextState: 2;  Action: actAccept),
   { cPercent   }(NextState: 2;  Action: actAccept),
   { cPower     }(NextState: 2;  Action: actAccept),
   { cNet       }(NextState: 2;  Action: actAccept),
   { cParamInd  }(NextState: 2;  Action: actAccept),
   { cStrTip    }(NextState: 2;  Action: actAccept),
   { cEOF       }(NextState: 2;  Action: actAccept))
                ),

   {State = 14}
        ( What : lexOperation;
          Attribute : (Operation: opPluss);
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 15}
        ( What : lexOperation;
          Attribute : (Operation: opMinus);
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 16}
        ( What : lexOperation;
          Attribute : (Operation: opMul);
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 17}
        ( What : lexOperation;
          Attribute : (Operation: opDiv);
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 18}
        ( What : lexOperation;
          Attribute : (Operation: opPower);
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 19}
        ( What : lexOperation;
          Attribute : (Operation: opMod);
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 20}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actError),
   { cSeparator }(NextState: 1;  Action: actError),
   { cDigit     }(NextState: 1;  Action: actError),
   { cAlpha     }(NextState: 21;  Action: actAppend),
   { cE         }(NextState: 21;  Action: actAppend),
   { cDPoint    }(NextState: 1;  Action: actError),
   { cComa      }(NextState: 1;  Action: actError),
   { cPComa     }(NextState: 1;  Action: actError),
   { cTwoPoints }(NextState: 1;  Action: actError),
   { cLeftArc   }(NextState: 1;  Action: actError),
   { cRightArc  }(NextState: 1;  Action: actError),
   { cLeftMArc  }(NextState: 1;  Action: actError),
   { cRightMArc }(NextState: 1;  Action: actError),
   { cLeftBArc  }(NextState: 1;  Action: actError),
   { cRightBArc }(NextState: 1;  Action: actError),
   { cPluss     }(NextState: 1;  Action: actError),
   { cMinus     }(NextState: 1;  Action: actError),
   { cStar      }(NextState: 1;  Action: actError),
   { cDiv       }(NextState: 1;  Action: actError),
   { cPercent   }(NextState: 1;  Action: actError),
   { cPower     }(NextState: 1;  Action: actError),
   { cNet       }(NextState: 1;  Action: actError),
   { cParamInd  }(NextState: 1;  Action: actError),
   { cStrTip    }(NextState: 1;  Action: actError),
   { cEOF       }(NextState: 1;  Action: actError))
                ),

   {State = 21}
        ( What : lexCommand;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 21;  Action: actAppend),
   { cAlpha     }(NextState: 21;  Action: actAppend),
   { cE         }(NextState: 21;  Action: actAppend),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 22}
        ( What : lexIdentifier;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 2;  Action: actAccept),
   { cSeparator }(NextState: 2;  Action: actAccept),
   { cDigit     }(NextState: 22;  Action: actAppend),
   { cAlpha     }(NextState: 22;  Action: actAppend),
   { cE         }(NextState: 22;  Action: actAppend),
   { cDPoint    }(NextState: 2;  Action: actAccept),
   { cComa      }(NextState: 2;  Action: actAccept),
   { cPComa     }(NextState: 2;  Action: actAccept),
   { cTwoPoints }(NextState: 2;  Action: actAccept),
   { cLeftArc   }(NextState: 2;  Action: actAccept),
   { cRightArc  }(NextState: 2;  Action: actAccept),
   { cLeftMArc  }(NextState: 2;  Action: actAccept),
   { cRightMArc }(NextState: 2;  Action: actAccept),
   { cLeftBArc  }(NextState: 2;  Action: actAccept),
   { cRightBArc }(NextState: 2;  Action: actAccept),
   { cPluss     }(NextState: 2;  Action: actAccept),
   { cMinus     }(NextState: 2;  Action: actAccept),
   { cStar      }(NextState: 2;  Action: actAccept),
   { cDiv       }(NextState: 2;  Action: actAccept),
   { cPercent   }(NextState: 2;  Action: actAccept),
   { cPower     }(NextState: 2;  Action: actAccept),
   { cNet       }(NextState: 2;  Action: actAccept),
   { cParamInd  }(NextState: 2;  Action: actAccept),
   { cStrTip    }(NextState: 2;  Action: actAccept),
   { cEOF       }(NextState: 2;  Action: actAccept))
                ),

   {State = 23}
        ( What : lexInteger;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 2;  Action: actAccept),
   { cSeparator }(NextState: 2;  Action: actAccept),
   { cDigit     }(NextState: 23;  Action: actAppend),
   { cAlpha     }(NextState: 2;  Action: actAccept),
   { cE         }(NextState: 26;  Action: actAppend),
   { cDPoint    }(NextState: 24;  Action: actAppend),
   { cComa      }(NextState: 2;  Action: actAccept),
   { cPComa     }(NextState: 2;  Action: actAccept),
   { cTwoPoints }(NextState: 2;  Action: actAccept),
   { cLeftArc   }(NextState: 2;  Action: actAccept),
   { cRightArc  }(NextState: 2;  Action: actAccept),
   { cLeftMArc  }(NextState: 2;  Action: actAccept),
   { cRightMArc }(NextState: 2;  Action: actAccept),
   { cLeftBArc  }(NextState: 2;  Action: actAccept),
   { cRightBArc }(NextState: 2;  Action: actAccept),
   { cPluss     }(NextState: 2;  Action: actAccept),
   { cMinus     }(NextState: 2;  Action: actAccept),
   { cStar      }(NextState: 2;  Action: actAccept),
   { cDiv       }(NextState: 2;  Action: actAccept),
   { cPercent   }(NextState: 2;  Action: actAccept),
   { cPower     }(NextState: 2;  Action: actAccept),
   { cNet       }(NextState: 2;  Action: actAccept),
   { cParamInd  }(NextState: 2;  Action: actAccept),
   { cStrTip    }(NextState: 2;  Action: actAccept),
   { cEOF       }(NextState: 2;  Action: actAccept))
                ),

   {State = 24}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actError),
   { cSeparator }(NextState: 1;  Action: actError),
   { cDigit     }(NextState: 25;  Action: actAppend),
   { cAlpha     }(NextState: 1;  Action: actError),
   { cE         }(NextState: 1;  Action: actError),
   { cDPoint    }(NextState: 1;  Action: actError),
   { cComa      }(NextState: 1;  Action: actError),
   { cPComa     }(NextState: 1;  Action: actError),
   { cTwoPoints }(NextState: 1;  Action: actError),
   { cLeftArc   }(NextState: 1;  Action: actError),
   { cRightArc  }(NextState: 1;  Action: actError),
   { cLeftMArc  }(NextState: 1;  Action: actError),
   { cRightMArc }(NextState: 1;  Action: actError),
   { cLeftBArc  }(NextState: 1;  Action: actError),
   { cRightBArc }(NextState: 1;  Action: actError),
   { cPluss     }(NextState: 1;  Action: actError),
   { cMinus     }(NextState: 1;  Action: actError),
   { cStar      }(NextState: 1;  Action: actError),
   { cDiv       }(NextState: 1;  Action: actError),
   { cPercent   }(NextState: 1;  Action: actError),
   { cPower     }(NextState: 1;  Action: actError),
   { cNet       }(NextState: 1;  Action: actError),
   { cParamInd  }(NextState: 1;  Action: actError),
   { cStrTip    }(NextState: 1;  Action: actError),
   { cEOF       }(NextState: 1;  Action: actError))
                ),

   {State = 25}
        ( What : lexFloat;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 2;  Action: actAccept),
   { cSeparator }(NextState: 2;  Action: actAccept),
   { cDigit     }(NextState: 25;  Action: actAppend),
   { cAlpha     }(NextState: 2;  Action: actAccept),
   { cE         }(NextState: 26;  Action: actAppend),
   { cDPoint    }(NextState: 2;  Action: actAccept),
   { cComa      }(NextState: 2;  Action: actAccept),
   { cPComa     }(NextState: 2;  Action: actAccept),
   { cTwoPoints }(NextState: 2;  Action: actAccept),
   { cLeftArc   }(NextState: 2;  Action: actAccept),
   { cRightArc  }(NextState: 2;  Action: actAccept),
   { cLeftMArc  }(NextState: 2;  Action: actAccept),
   { cRightMArc }(NextState: 2;  Action: actAccept),
   { cLeftBArc  }(NextState: 2;  Action: actAccept),
   { cRightBArc }(NextState: 2;  Action: actAccept),
   { cPluss     }(NextState: 2;  Action: actAccept),
   { cMinus     }(NextState: 2;  Action: actAccept),
   { cStar      }(NextState: 2;  Action: actAccept),
   { cDiv       }(NextState: 2;  Action: actAccept),
   { cPercent   }(NextState: 2;  Action: actAccept),
   { cPower     }(NextState: 2;  Action: actAccept),
   { cNet       }(NextState: 2;  Action: actAccept),
   { cParamInd  }(NextState: 2;  Action: actAccept),
   { cStrTip    }(NextState: 2;  Action: actAccept),
   { cEOF       }(NextState: 2;  Action: actAccept))
                ),

   {State = 26}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actError),
   { cSeparator }(NextState: 1;  Action: actError),
   { cDigit     }(NextState: 27;  Action: actAppend),
   { cAlpha     }(NextState: 1;  Action: actError),
   { cE         }(NextState: 1;  Action: actError),
   { cDPoint    }(NextState: 1;  Action: actError),
   { cComa      }(NextState: 1;  Action: actError),
   { cPComa     }(NextState: 1;  Action: actError),
   { cTwoPoints }(NextState: 1;  Action: actError),
   { cLeftArc   }(NextState: 1;  Action: actError),
   { cRightArc  }(NextState: 1;  Action: actError),
   { cLeftMArc  }(NextState: 1;  Action: actError),
   { cRightMArc }(NextState: 1;  Action: actError),
   { cLeftBArc  }(NextState: 1;  Action: actError),
   { cRightBArc }(NextState: 1;  Action: actError),
   { cPluss     }(NextState: 27;  Action: actAppend),
   { cMinus     }(NextState: 27;  Action: actAppend),
   { cStar      }(NextState: 1;  Action: actError),
   { cDiv       }(NextState: 1;  Action: actError),
   { cPercent   }(NextState: 1;  Action: actError),
   { cPower     }(NextState: 1;  Action: actError),
   { cNet       }(NextState: 1;  Action: actError),
   { cParamInd  }(NextState: 1;  Action: actError),
   { cStrTip    }(NextState: 1;  Action: actError),
   { cEOF       }(NextState: 1;  Action: actError))
                ),

   {State = 27}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actError),
   { cSeparator }(NextState: 1;  Action: actError),
   { cDigit     }(NextState: 28;  Action: actAppend),
   { cAlpha     }(NextState: 1;  Action: actError),
   { cE         }(NextState: 1;  Action: actError),
   { cDPoint    }(NextState: 1;  Action: actError),
   { cComa      }(NextState: 1;  Action: actError),
   { cPComa     }(NextState: 1;  Action: actError),
   { cTwoPoints }(NextState: 1;  Action: actError),
   { cLeftArc   }(NextState: 1;  Action: actError),
   { cRightArc  }(NextState: 1;  Action: actError),
   { cLeftMArc  }(NextState: 1;  Action: actError),
   { cRightMArc }(NextState: 1;  Action: actError),
   { cLeftBArc  }(NextState: 1;  Action: actError),
   { cRightBArc }(NextState: 1;  Action: actError),
   { cPluss     }(NextState: 1;  Action: actError),
   { cMinus     }(NextState: 1;  Action: actError),
   { cStar      }(NextState: 1;  Action: actError),
   { cDiv       }(NextState: 1;  Action: actError),
   { cPercent   }(NextState: 1;  Action: actError),
   { cPower     }(NextState: 1;  Action: actError),
   { cNet       }(NextState: 1;  Action: actError),
   { cParamInd  }(NextState: 1;  Action: actError),
   { cStrTip    }(NextState: 1;  Action: actError),
   { cEOF       }(NextState: 1;  Action: actError))
                ),

   {State = 28}
        ( What : lexFloat;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 2;  Action: actAccept),
   { cSeparator }(NextState: 2;  Action: actAccept),
   { cDigit     }(NextState: 28;  Action: actAppend),
   { cAlpha     }(NextState: 2;  Action: actAccept),
   { cE         }(NextState: 2;  Action: actAccept),
   { cDPoint    }(NextState: 2;  Action: actAccept),
   { cComa      }(NextState: 2;  Action: actAccept),
   { cPComa     }(NextState: 2;  Action: actAccept),
   { cTwoPoints }(NextState: 2;  Action: actAccept),
   { cLeftArc   }(NextState: 2;  Action: actAccept),
   { cRightArc  }(NextState: 2;  Action: actAccept),
   { cLeftMArc  }(NextState: 2;  Action: actAccept),
   { cRightMArc }(NextState: 2;  Action: actAccept),
   { cLeftBArc  }(NextState: 2;  Action: actAccept),
   { cRightBArc }(NextState: 2;  Action: actAccept),
   { cPluss     }(NextState: 2;  Action: actAccept),
   { cMinus     }(NextState: 2;  Action: actAccept),
   { cStar      }(NextState: 2;  Action: actAccept),
   { cDiv       }(NextState: 2;  Action: actAccept),
   { cPercent   }(NextState: 2;  Action: actAccept),
   { cPower     }(NextState: 2;  Action: actAccept),
   { cNet       }(NextState: 2;  Action: actAccept),
   { cParamInd  }(NextState: 2;  Action: actAccept),
   { cStrTip    }(NextState: 2;  Action: actAccept),
   { cEOF       }(NextState: 2;  Action: actAccept))
                ),

   {State = 29}
        ( What : lexMacroBody;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),

   {State = 30}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actError),
   { cSeparator }(NextState: 30;  Action: actSkip),
   { cDigit     }(NextState: 23;  Action: actAppend),
   { cAlpha     }(NextState: 22;  Action: actAppend),
   { cE         }(NextState: 22;  Action: actAppend),
   { cDPoint    }(NextState: 6;  Action: actAppend),
   { cComa      }(NextState: 3;  Action: actAppend),
   { cPComa     }(NextState: 4;  Action: actAppend),
   { cTwoPoints }(NextState: 5;  Action: actAppend),
   { cLeftArc   }(NextState: 12;  Action: actAppend),
   { cRightArc  }(NextState: 13;  Action: actAppend),
   { cLeftMArc  }(NextState: 10;  Action: actAppend),
   { cRightMArc }(NextState: 11;  Action: actAppend),
   { cLeftBArc  }(NextState: 7;  Action: actAppend),
   { cRightBArc }(NextState: 1;  Action: actError),
   { cPluss     }(NextState: 1;  Action: actError),
   { cMinus     }(NextState: 1;  Action: actError),
   { cStar      }(NextState: 1;  Action: actError),
   { cDiv       }(NextState: 1;  Action: actError),
   { cPercent   }(NextState: 1;  Action: actError),
   { cPower     }(NextState: 1;  Action: actError),
   { cNet       }(NextState: 20;  Action: actAppend),
   { cParamInd  }(NextState: 31;  Action: actAppend),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actStop))
                ),

   {State = 31}
        ( What : lexParamInd;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ),
   {State = 32}
        ( What : lexNone;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 32;  Action: actAppendToBuffer),
   { cSeparator }(NextState: 32;  Action: actAppendToBuffer),
   { cDigit     }(NextState: 32;  Action: actAppendToBuffer),
   { cAlpha     }(NextState: 32;  Action: actAppendToBuffer),
   { cE         }(NextState: 32;  Action: actAppendToBuffer),
   { cDPoint    }(NextState: 32;  Action: actAppendToBuffer),
   { cComa      }(NextState: 32;  Action: actAppendToBuffer),
   { cPComa     }(NextState: 32;  Action: actAppendToBuffer),
   { cTwoPoints }(NextState: 32;  Action: actAppendToBuffer),
   { cLeftArc   }(NextState: 32;  Action: actAppendToBuffer),
   { cRightArc  }(NextState: 32;  Action: actAppendToBuffer),
   { cLeftMArc  }(NextState: 32;  Action: actAppendToBuffer),
   { cRightMArc }(NextState: 32;  Action: actAppendToBuffer),
   { cLeftBArc  }(NextState: 32;  Action: actAppendToBuffer),
   { cRightBArc }(NextState: 32;  Action: actAppendToBuffer),
   { cPluss     }(NextState: 32;  Action: actAppendToBuffer),
   { cMinus     }(NextState: 32;  Action: actAppendToBuffer),
   { cStar      }(NextState: 32;  Action: actAppendToBuffer),
   { cDiv       }(NextState: 32;  Action: actAppendToBuffer),
   { cPercent   }(NextState: 32;  Action: actAppendToBuffer),
   { cPower     }(NextState: 32;  Action: actAppendToBuffer),
   { cNet       }(NextState: 32;  Action: actAppendToBuffer),
   { cParamInd  }(NextState: 32;  Action: actAppendToBuffer),
   { cStrTip    }(NextState: 33;  Action: actAppend),
   { cEOF       }(NextState: 32;  Action: actError))
                ),

   {State = 33}
        ( What : lexString;
          Attribute : ();
          Table : (
   { cChar      }(NextState: 1;  Action: actAccept),
   { cSeparator }(NextState: 1;  Action: actAccept),
   { cDigit     }(NextState: 1;  Action: actAccept),
   { cAlpha     }(NextState: 1;  Action: actAccept),
   { cE         }(NextState: 1;  Action: actAccept),
   { cDPoint    }(NextState: 1;  Action: actAccept),
   { cComa      }(NextState: 1;  Action: actAccept),
   { cPComa     }(NextState: 1;  Action: actAccept),
   { cTwoPoints }(NextState: 1;  Action: actAccept),
   { cLeftArc   }(NextState: 1;  Action: actAccept),
   { cRightArc  }(NextState: 1;  Action: actAccept),
   { cLeftMArc  }(NextState: 1;  Action: actAccept),
   { cRightMArc }(NextState: 1;  Action: actAccept),
   { cLeftBArc  }(NextState: 1;  Action: actAccept),
   { cRightBArc }(NextState: 1;  Action: actAccept),
   { cPluss     }(NextState: 1;  Action: actAccept),
   { cMinus     }(NextState: 1;  Action: actAccept),
   { cStar      }(NextState: 1;  Action: actAccept),
   { cDiv       }(NextState: 1;  Action: actAccept),
   { cPercent   }(NextState: 1;  Action: actAccept),
   { cPower     }(NextState: 1;  Action: actAccept),
   { cNet       }(NextState: 1;  Action: actAccept),
   { cParamInd  }(NextState: 1;  Action: actAccept),
   { cStrTip    }(NextState: 1;  Action: actAccept),
   { cEOF       }(NextState: 1;  Action: actAccept))
                ));

   CharsArray : TCharsArray = (
       { #  0 }  (T: cEOF),
       { #  1 }  (T: cSeparator),
       { #  2 }  (T: cSeparator),
       { #  3 }  (T: cSeparator),
       { #  4 }  (T: cSeparator),
       { #  5 }  (T: cSeparator),
       { #  6 }  (T: cSeparator),
       { #  7 }  (T: cSeparator),
       { #  8 }  (T: cSeparator),
       { #  9 }  (T: cSeparator),
       { # 10 }  (T: cSeparator),
       { # 11 }  (T: cSeparator),
       { # 12 }  (T: cSeparator),
       { # 13 }  (T: cSeparator),
       { # 14 }  (T: cSeparator),
       { # 15 }  (T: cSeparator),
       { # 16 }  (T: cSeparator),
       { # 17 }  (T: cSeparator),
       { # 18 }  (T: cSeparator),
       { # 19 }  (T: cSeparator),
       { # 20 }  (T: cSeparator),
       { # 21 }  (T: cSeparator),
       { # 22 }  (T: cSeparator),
       { # 23 }  (T: cSeparator),
       { # 24 }  (T: cSeparator),
       { # 25 }  (T: cSeparator),
       { # 26 }  (T: cSeparator),
       { # 27 }  (T: cSeparator),
       { # 28 }  (T: cSeparator),
       { # 29 }  (T: cSeparator),
       { # 30 }  (T: cSeparator),
       { # 31 }  (T: cSeparator),
       {     }   (T: cSeparator),
       {  !  }   (T: cChar),
       {  "  }   (T: cStrTip),
       {  #  }   (T: cNet),
       {  $  }   (T: cChar),
       {  %  }   (T: cPercent),
       {  &  }   (T: cChar),
       {  '  }   (T: cChar),
       {  (  }   (T: cLeftArc),
       {  )  }   (T: cRightArc),
       {  *  }   (T: cStar),
       {  +  }   (T: cPluss),
       {  ,  }   (T: cComa),
       {  -  }   (T: cMinus),
       {  .  }   (T: cDPoint),
       {  /  }   (T: cDiv),
       {  0  }   (T: cDigit),
       {  1  }   (T: cDigit),
       {  2  }   (T: cDigit),
       {  3  }   (T: cDigit),
       {  4  }   (T: cDigit),
       {  5  }   (T: cDigit),
       {  6  }   (T: cDigit),
       {  7  }   (T: cDigit),
       {  8  }   (T: cDigit),
       {  9  }   (T: cDigit),
       {  :  }   (T: cTwoPoints),
       {  ;  }   (T: cPComa),
       {  <  }   (T: cChar),
       {  =  }   (T: cChar),
       {  >  }   (T: cChar),
       {  ?  }   (T: cChar),
       {  @  }   (T: cParamInd),
       {  A  }   (T: cAlpha),
       {  B  }   (T: cAlpha),
       {  C  }   (T: cAlpha),
       {  D  }   (T: cAlpha),
       {  E  }   (T: cE),
       {  F  }   (T: cAlpha),
       {  G  }   (T: cAlpha),
       {  H  }   (T: cAlpha),
       {  I  }   (T: cAlpha),
       {  J  }   (T: cAlpha),
       {  K  }   (T: cAlpha),
       {  L  }   (T: cAlpha),
       {  M  }   (T: cAlpha),
       {  N  }   (T: cAlpha),
       {  O  }   (T: cAlpha),
       {  P  }   (T: cAlpha),
       {  Q  }   (T: cAlpha),
       {  R  }   (T: cAlpha),
       {  S  }   (T: cAlpha),
       {  T  }   (T: cAlpha),
       {  U  }   (T: cAlpha),
       {  V  }   (T: cAlpha),
       {  W  }   (T: cAlpha),
       {  X  }   (T: cAlpha),
       {  Y  }   (T: cAlpha),
       {  Z  }   (T: cAlpha),
       {  [  }   (T: cLeftMArc),
       {  \  }   (T: cChar),
       {  ]  }   (T: cRightMArc),
       {  ^  }   (T: cPower),
       {  _  }   (T: cAlpha),
       {  `  }   (T: cChar),
       {  a  }   (T: cAlpha),
       {  b  }   (T: cAlpha),
       {  c  }   (T: cAlpha),
       {  d  }   (T: cAlpha),
       {  e  }   (T: cE),
       {  f  }   (T: cAlpha),
       {  g  }   (T: cAlpha),
       {  h  }   (T: cAlpha),
       {  i  }   (T: cAlpha),
       {  j  }   (T: cAlpha),
       {  k  }   (T: cAlpha),
       {  l  }   (T: cAlpha),
       {  m  }   (T: cAlpha),
       {  n  }   (T: cAlpha),
       {  o  }   (T: cAlpha),
       {  p  }   (T: cAlpha),
       {  q  }   (T: cAlpha),
       {  r  }   (T: cAlpha),
       {  s  }   (T: cAlpha),
       {  t  }   (T: cAlpha),
       {  u  }   (T: cAlpha),
       {  v  }   (T: cAlpha),
       {  w  }   (T: cAlpha),
       {  x  }   (T: cAlpha),
       {  y  }   (T: cAlpha),
       {  z  }   (T: cAlpha),
       {  {  }   (T: cLeftBArc),
       {  |  }   (T: cChar),
       (* } *)   (T: cRightBArc),
       {  ~  }   (T: cChar),
       {    }   (T: cChar),
       {  Ä  }   (T: cChar),
       {  Å  }   (T: cChar),
       {  Ç  }   (T: cChar),
       {  É  }   (T: cChar),
       {  Ñ  }   (T: cChar),
       {  Ö  }   (T: cChar),
       {  Ü  }   (T: cChar),
       {  á  }   (T: cChar),
       {  à  }   (T: cChar),
       {  â  }   (T: cChar),
       {  ä  }   (T: cChar),
       {  ã  }   (T: cChar),
       {  å  }   (T: cChar),
       {  ç  }   (T: cChar),
       {  é  }   (T: cChar),
       {  è  }   (T: cChar),
       {  ê  }   (T: cChar),
       {  ë  }   (T: cChar),
       {  í  }   (T: cChar),
       {  ì  }   (T: cChar),
       {  î  }   (T: cChar),
       {  ï  }   (T: cChar),
       {  ñ  }   (T: cChar),
       {  ó  }   (T: cChar),
       {  ò  }   (T: cChar),
       {  ô  }   (T: cChar),
       {  ö  }   (T: cChar),
       {  õ  }   (T: cChar),
       {  ú  }   (T: cChar),
       {  ù  }   (T: cChar),
       {  û  }   (T: cChar),
       {  ü  }   (T: cChar),
       {  †  }   (T: cChar),
       {  °  }   (T: cChar),
       {  ¢  }   (T: cChar),
       {  £  }   (T: cChar),
       {  §  }   (T: cChar),
       {  •  }   (T: cChar),
       {  ¶  }   (T: cChar),
       {  ß  }   (T: cChar),
       {  ®  }   (T: cChar),
       {  ©  }   (T: cChar),
       {  ™  }   (T: cChar),
       {  ´  }   (T: cChar),
       {  ¨  }   (T: cChar),
       {  ≠  }   (T: cChar),
       {  Æ  }   (T: cChar),
       {  Ø  }   (T: cChar),
       {  ∞  }   (T: cChar),
       {  ±  }   (T: cChar),
       {  ≤  }   (T: cChar),
       {  ≥  }   (T: cChar),
       {  ¥  }   (T: cChar),
       {  µ  }   (T: cChar),
       {  ∂  }   (T: cChar),
       {  ∑  }   (T: cChar),
       {  ∏  }   (T: cChar),
       {  π  }   (T: cChar),
       {  ∫  }   (T: cChar),
       {  ª  }   (T: cChar),
       {  º  }   (T: cChar),
       {  Ω  }   (T: cChar),
       {  æ  }   (T: cChar),
       {  ø  }   (T: cChar),
       {  ¿  }   (T: cChar),
       {  ¡  }   (T: cChar),
       {  ¬  }   (T: cChar),
       {  √  }   (T: cChar),
       {  ƒ  }   (T: cChar),
       {  ≈  }   (T: cChar),
       {  ∆  }   (T: cChar),
       {  «  }   (T: cChar),
       {  »  }   (T: cChar),
       {  …  }   (T: cChar),
       {     }   (T: cChar),
       {  À  }   (T: cChar),
       {  Ã  }   (T: cChar),
       {  Õ  }   (T: cChar),
       {  Œ  }   (T: cChar),
       {  œ  }   (T: cChar),
       {  –  }   (T: cChar),
       {  —  }   (T: cChar),
       {  “  }   (T: cChar),
       {  ”  }   (T: cChar),
       {  ‘  }   (T: cChar),
       {  ’  }   (T: cChar),
       {  ÷  }   (T: cChar),
       {  ◊  }   (T: cChar),
       {  ÿ  }   (T: cChar),
       {  Ÿ  }   (T: cChar),
       {  ⁄  }   (T: cChar),
       {  €  }   (T: cChar),
       {  ‹  }   (T: cChar),
       {  ›  }   (T: cChar),
       {  ﬁ  }   (T: cChar),
       {  ﬂ  }   (T: cChar),
       {  ‡  }   (T: cChar),
       {  ·  }   (T: cChar),
       {  ‚  }   (T: cChar),
       {  „  }   (T: cChar),
       {  ‰  }   (T: cChar),
       {  Â  }   (T: cChar),
       {  Ê  }   (T: cChar),
       {  Á  }   (T: cChar),
       {  Ë  }   (T: cChar),
       {  È  }   (T: cChar),
       {  Í  }   (T: cChar),
       {  Î  }   (T: cChar),
       {  Ï  }   (T: cChar),
       {  Ì  }   (T: cChar),
       {  Ó  }   (T: cChar),
       {  Ô  }   (T: cChar),
       {    }   (T: cChar),
       {  Ò  }   (T: cChar),
       {  Ú  }   (T: cChar),
       {  Û  }   (T: cChar),
       {  Ù  }   (T: cChar),
       {  ı  }   (T: cChar),
       {  ˆ  }   (T: cChar),
       {  ˜  }   (T: cChar),
       {  ¯  }   (T: cChar),
       {  ˘  }   (T: cChar),
       {  ˙  }   (T: cChar),
       {  ˚  }   (T: cChar),
       {  ¸  }   (T: cChar),
       {  ˝  }   (T: cChar),
       {  ˛  }   (T: cChar),
       {  ˇ  }   (T: cChar));


constructor TSource.Create;
begin
     inherited Create;
     CurrentState := 1;
     GetMem( Buffer, BUFFERSIZE);
     BufferCursor := Buffer;
end;

destructor TSource.Destroy;
begin
     FreeMem( Buffer, BUFFERSIZE);
     BufferCursor := nil;
     Buffer := nil;
     inherited Destroy;
end;

procedure TSource.Reset;
begin
     CurrentState := 1;
end;

procedure TSource.MoveForward;
begin
end;

function TSource.GetChar;
begin
     GetChar := #0;
end;

function TSource.NextLexican: TLexican;
var Character: TCharacter;
    C: Char;
begin
     CurrentLexicanString := '';
     BufferCursor := Buffer;
     BufferUsed := 0;
     while True
     do begin
        C := GetChar;
        Character := CharsArray[ C].T;
        case States[ CurrentState].Table[ Character].Action
        of actAppend:
               begin
               CurrentLexicanString := CurrentLexicanString + C;
               CurrentState := States[ CurrentState].Table[ Character].NextState;
               MoveForward;
               end;
           actSkip:
               begin
               CurrentState := States[ CurrentState].Table[ Character].NextState;
               MoveForward;
               end;
           actAccept:
               begin
               CurrentLexican := States[ CurrentState].What;
               CurrentLexicanAttr := States[ CurrentState].Attribute;
               CurrentState := States[ CurrentState].Table[ Character].NextState;
               NextLexican := CurrentLexican;
               exit;
               end;
           actAppendToBuffer:
               begin
               if (BufferUsed < BUFFERSIZE)
               then begin
                    BufferCursor^ := C;
                    BufferCursor := BufferCursor + 1;
                    BufferUsed := BufferUsed + 1;
                    end;
               CurrentState := States[ CurrentState].Table[ Character].NextState;
               MoveForward;
               end;
           actStop:
               begin
               CurrentLexican := lexNone;
               CurrentState := States[ CurrentState].Table[ Character].NextState;
               NextLexican := CurrentLexican;
               exit;
               end;
           actError:
               begin
               CurrentLexican := lexError;
               CurrentState := States[ CurrentState].Table[ Character].NextState;
               NextLexican := CurrentLexican;
               exit;
               end;
           end;
        end;
end;

function TSource.Lexican: TLexican;
begin
     Lexican := CurrentLexican;
end;

function TSource.LexicanString: string;
begin
     LexicanString := CurrentLexicanString;
end;

function TSource.GetLexicanAttribute( var AAttr: TLexicanAttribute): Boolean;
var Code: Integer;
begin
     case CurrentLexican of
     lexInteger: begin
                 Val( CurrentLexicanString, AAttr.IntegerValue, Code);
                 GetLexicanAttribute := True;
                 end;
     lexFloat: begin
               Val( CurrentLexicanString, AAttr.FloatValue, Code);
               GetLexicanAttribute := True;
               end;
     lexMacroBody: begin
                   AAttr.Buffer := Buffer;
                   AAttr.BufferSize := ( BufferUsed);
                   BufferCursor^ := #0;
                   GetLexicanAttribute := True;
                   end;
     lexString: begin
                AAttr.Buffer := Buffer;
                AAttr.BufferSize := ( BufferUsed);
                BufferCursor^ := #0;
                GetLexicanAttribute := True;
                end;
     lexOperation: begin
                   AAttr := CurrentLexicanAttr;
                   GetLexicanAttribute := True;
                   end;
     else
         GetLexicanAttribute := False;
     end
end;


constructor TFileSource.Create( ASourceStream: PStream);
begin
     inherited Create;
     SourceStream := ASourceStream;
     if ( SourceStream <> nil)
     then begin
          SourceStream^.Seek(0);
          if (( SourceStream^.GetSize - SourceStream^.GetPos) >= FILEBUFFERSIZE)
          then begin
               SourceStream^.Read( FileBuffer, FILEBUFFERSIZE);
               FileBufferUsed := FILEBUFFERSIZE;
               end
          else begin
               FileBufferUsed := SourceStream^.GetSize - SourceStream^.GetPos;
               SourceStream^.Read( FileBuffer, FileBufferUsed);
               end;
          end
     else FileBufferUsed := 0;
     FileBuffer[ FileBufferUsed + 1] := #0;
     FileBufferCursor := 1;
     LineNo := 1;
     ColNo := 0;
end;

destructor TFileSource.Destroy;
begin
     inherited Destroy;
end;

procedure TFileSource.Reset;
begin
     inherited Reset;
     if ( SourceStream <> nil)
     then begin
          SourceStream^.Seek( 0);
          if (( SourceStream^.GetSize - SourceStream^.GetPos) >= FILEBUFFERSIZE)
          then begin
               SourceStream^.Read( FileBuffer, FILEBUFFERSIZE);
               FileBufferUsed := FILEBUFFERSIZE;
               end
          else begin
               FileBufferUsed := SourceStream^.GetSize - SourceStream^.GetPos;
               SourceStream^.Read( FileBuffer, FileBufferUsed);
               end;
          end
     else FileBufferUsed := 0;
     FileBuffer[ FileBufferUsed + 1] := #0;
     FileBufferCursor := 1;
     LineNo := 1;
     ColNo := 0;
end;

procedure TFileSource.MoveForward;
begin
     if ( FileBufferCursor < FileBufferUsed)
     then FileBufferCursor := FileBufferCursor + 1
     else begin
          if ( SourceStream <> nil)
          then begin
               if (( SourceStream^.GetSize - SourceStream^.GetPos) >= FILEBUFFERSIZE)
               then begin
                    SourceStream^.Read( FileBuffer, FILEBUFFERSIZE);
                    FileBufferUsed := FILEBUFFERSIZE;
                    end
               else begin
                    FileBufferUsed := SourceStream^.GetSize - SourceStream^.GetPos;
                    SourceStream^.Read( FileBuffer, FileBufferUsed);
                    end;
               end
          else FileBufferUsed := 0;

          FileBuffer[ FileBufferUsed + 1] := #0;
          FileBufferCursor := 1;
          end;
     if FileBuffer[ FileBufferCursor] = #10
     then begin
          LineNo := LineNo + 1;
          ColNo := 0;
          end
     else ColNo := ColNo + 1;
end;

function TFileSource.GetChar: Char;
begin
     GetChar := FileBuffer[ FileBufferCursor];
end;

function TFileSource.GetLineNo: Longint;
begin
     GetLineNo := LineNo;
end;

function TFileSource.GetColNo: Longint;
begin
     GetColNo := ColNo;
end;


constructor TStringSource.Create( AStr: string);
begin
     inherited Create;
     Str := AStr + #0;
     Cursor := 1;
end;

destructor TStringSource.Destroy;
begin
     inherited Destroy;
end;

procedure TStringSource.Reset;
begin
     inherited Reset;
     Cursor := 1;
end;

procedure TStringSource.MoveForward;
begin
     Cursor := Cursor + 1;
end;

function TStringSource.GetChar: Char;
begin
     GetChar := Str[ Cursor];
end;

function TStringSource.GetCursorPos: Longint;
begin
     GetCursorPos := Cursor;
end;

end.