unit praxo_retriever;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, praxo;

type
  EPraxoRetriever = class(Exception)
  public
    Code: UTF8String;
    constructor CreateCode(const ACode, AMessage: UTF8String);
  end;

  TPraxoDocument = record
    Id, Content: UTF8String;
    Metadata: TJSONData;
    Score: Double;
    HasScore: Boolean;
  end;
  TPraxoDocuments = array of TPraxoDocument;

  TPraxoRetriever = function(const Query: UTF8String;
    Limit: Integer): TPraxoDocuments;

  TPraxoFuncRetriever = class
  public
    Retrieve: TPraxoRetriever;
    constructor Create(ARetrieve: TPraxoRetriever);
    function Run(const Query: UTF8String; Limit: Integer): TPraxoDocuments;
  end;

function PraxoDocument(const Id, Content: UTF8String; Metadata: TJSONData = nil;
  Score: Double = 0; HasScore: Boolean = False): TPraxoDocument;
function PraxoRetrieveDocuments(Retriever: TPraxoRetriever;
  const Query: UTF8String; Limit: Integer): TPraxoDocuments;

implementation

constructor EPraxoRetriever.CreateCode(const ACode, AMessage: UTF8String);
begin
  inherited Create(AMessage);
  Code := ACode;
end;

function PraxoDocument(const Id, Content: UTF8String; Metadata: TJSONData;
  Score: Double; HasScore: Boolean): TPraxoDocument;
begin
  Result.Id := Id;
  Result.Content := Content;
  Result.Metadata := Metadata;
  Result.Score := Score;
  Result.HasScore := HasScore;
end;

constructor TPraxoFuncRetriever.Create(ARetrieve: TPraxoRetriever);
begin
  inherited Create;
  Retrieve := ARetrieve;
end;

function TPraxoFuncRetriever.Run(const Query: UTF8String;
  Limit: Integer): TPraxoDocuments;
begin
  Result := PraxoRetrieveDocuments(Retrieve, Query, Limit);
end;

function PraxoRetrieveDocuments(Retriever: TPraxoRetriever;
  const Query: UTF8String; Limit: Integer): TPraxoDocuments;
begin
  if Limit < 0 then
    raise EPraxoRetriever.CreateCode('RETRIEVER_INVALID',
      'retriever: invalid limit');
  if not Assigned(Retriever) then
    raise EPraxoRetriever.CreateCode('RETRIEVER_INVALID',
      'retriever: callback is required');
  Result := Retriever(Query, Limit);
end;

end.
