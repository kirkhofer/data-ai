# Batch Processing in ADX
The following example is a good example of a standard process of landing raw data and then flattening out via Update Policy (like a trigger in SQL) to other tables and materialized views for best performance

## Setup a free cluster
Go to https://dataexplorer.azure.com/ and create a free cluster with a database. 
> Use SHIFT+ENTER to execute one line no matter where you are

Use this [Quickstart](https://learn.microsoft.com/en-us/azure/data-explorer/start-for-free-web-ui) to see how it completely works

## Take a look and explore the cluster
```kusto
.show cluster
```
> Free cluster just has one node
## Create the first table 
Create the table SalesRaw
```kusto
.create table SalesRaw(RawData:dynamic)
```
Set the retention policy to 0. We won't keep data in this table long-term
```kusto
.alter-merge table SalesRaw policy retention softdelete = 0s
```
## Create aggregation table
Create the table with the true items in it
> We could have done this with a mapping directly from the source but we also want to add a unique key (guid) to this table so it is a bit different

> Plus, with schema shift, just loading raw data in the first table will help avoid issues down the road
```kusto
.create table TotalSales(salesId:guid,salesDate:datetime,amount:real,products:dynamic)
```
## Create the function to load the table
This function will be used to load the TotalSales table we just created

```kusto
.create function TotalSales_Update()
{
    SalesRaw
    | extend salesId=new_guid()
    | extend salesDate=todatetime(RawData["salesDate"])
    | extend salesAmt=todouble(RawData["salesAmt"])
    | project salesId,salesDate,amount=salesAmt,products=todynamic(RawData.products)
}
```
> Issues with the table can be testing with `TotalSales_Update() | getschema` to make sure the schema matches

> You could also create the table with this function easily `.set-or-append TotalSales <| TotalSales_Update() | limit 0`

## Associate the function to the table
Use an alter statement to set the policy
```kusto
.alter table TotalSales policy update @'[{"IsEnabled": true,"Source": "SalesRaw","Query": "TotalSales_Update()","IsTransactional": true,"PropagateIngestionProperties": false}]'
```
> You can disable this at anytime but called with IsEnabled = false

## Create a deduplication view
We need to make sure no duplicates make way into the table so create a deduplication view
```kusto
.create materialized-view TotalSales_Dedup on table TotalSales
{
    TotalSales
    | summarize take_any(*) by salesId,salesDate
}
```

## Create the summary materialized view
Create a summary view on top of the deduplication view to aggregate quarterly values
```kusto
.create materialized-view TotalSales_Quarterly on table TotalSales
{
    TotalSales
    | summarize salesAmt=sum(amount), salesCount=count() by Year=datetime_part("Year",salesDate), Quarter=datetime_part("Quarter", salesDate)
}
```

# Load data with a sample script
This code block can be ran over and over to produce random results from 2022-01-01 to the end of the year with random product keys and quantity
```kusto
.append SalesRaw <|
    let max=toint(rand(500))+100;
    let x=range(1,1000,1);
    let startTime=datetime(2022-01-01);
    let days=365;
    range Days from 1 to max step 1
    | extend dt=datetime_add("Day",toint(rand(days)),startTime)
    | extend amt=(rand(5)+1)*10000.00
    | project RawData=todynamic(strcat('{"salesDate":"',dt,'","salesAmt":',amt,',"products":[{"key":',x[toint(rand(array_length(x)))],',"qty":',toint(rand(100)+1),'},{"key":',x[toint(rand(array_length(x)))],',"qty":',toint(rand(100)+1),'}]}'))
```

Take a look at the counts
```kusto
// Notice there are no rows here because of the retention policy
SalesRaw|count

TotalSales|count

TotalSales_Quarterly|summarize sum(salesCount)
```
You should see something like this:
|Year|Quarter|salesAmt|salesCount|
|--|--|--|--|
|2022|1|99999|99|
|2022|2|99999|99|
|2022|3|99999|99|
|2022|4|99999|99|
## Validate what happens over time
1. Run the `.append` from above over and over 
1. Verify the results are what you would expect
```kusto
let origAmt=toscalar(TotalSales|summarize sum(amount));
let origCnt=toscalar(TotalSales|count);
let aggAmt=toscalar(TotalSales_Quarterly|summarize sum(salesAmt));
let dedupAmt=toscalar(TotalSales_Dedup|summarize sum(amount));
let dedupCnt=toscalar(TotalSales_Dedup|count);
print origAmt=origAmt,
    aggAmt=aggAmt,
    dedupAmt=dedupAmt,
    OrigAggAmount_Diff=origAmt-aggAmt,
    OrigDedupAmount_Diff=origAmt-dedupAmt,
    OrigDedupCnt_Diff=origCnt-dedupCnt
```
    - Notice the `_Diff` should be 0
1. See how many extents/shards you have 
```kusto
.show database extents
| summarize sum(OriginalSize),sum(ExtentSize) by TableName
| extend compRatio = sum_OriginalSize/sum_ExtentSize
```
## Best practices
- For a historical load it is best to set the `creationTime` of files being loaded to the actual historical date. This way the extents are created correctly and the system knows when it was loaded and can apply the correct retention policies
- If you create a materialized-view over existing table, you need to use the `with (backfill=true)` otherwise you will ONLY see data on new inserts

# Cleanup
```kusto
.drop table TotalSales ifexists 

.drop function TotalSales_Update ifexists

.drop materialized-view TotalSales_Quarterly ifexists

.drop materialized-view TotalSales_Dedup ifexists

.drop table SalesRaw ifexists 
```
