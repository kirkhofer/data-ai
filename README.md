# data-ai
Repo to share things I have learned over my many years of programming and data experiences

Find [News](news.md) over there...

# Captain's Log
## 2024-12-19 🎅🎄
- 🆕 Azure AI Agent Service [movie-agent](aoai/movie-agent.ipynb)
    - Can't believe it was Feb 24 when Assistants came out in Preview and is still in Preview
    - This new service will be a product with robust features and integrate well with Copilot or your own UI

## 2024-09-30
- 🆕 Notebook for [Tropical storms](map/storm-map.ipynb) using Azure Maps
    - I have always enjoyed creating content with weather and maps
    - And of course we got storm "Kirk" this year! At least it is staying in the middle of the ocean
## 2024-08-21
- 🆕 Notebook for [load testing](aoai/load-tester.ipynb) Azure OpenAI 
    > NOTE: You can twist this many ways as needed 

## 2024-08-14
- 🆕 Notebook to show [capacity](aoai/capacity.ipynb) in Azure OpenAI

## 2024-08-06
- 🆙 [SQL Tester](sql/README.md#sql-tester) added some code to output the total sessions in use

## 2024-06-25
- 🆕 [Fabric APIs](fabric/README.md#fabric-apis) notebook and all

## 2024-06-18
- 🆕 [SQL Tester](sql/README.md#sql-tester) to validate connection pools 

## 2024-06-04
- 🆙 Updates for APIM using the new backends and circuit breakers see [here](aoai/apim.md)
    > NOTE: This truly simplifies management and APIM manages a lot of this for you now

## 2024-03-20
- Added Azure Automation script to suspend [Fabric Capacity](fabric/README.md)

## 2024-02-22
- Pricing and Model variants helper [pricing](aoai/pricing.ipynb)

## 2024-02-06
- 🆕 Assistants API notebook with a file [movie-assistant](aoai/movie-assistant.ipynb)

## 2024-01-28
- 🥵 Azure API Management with Azure OpenAI retry 429 logic [here](aoai/apim.md)

## 2024-01-20
- Prompt Flow replacement for bing it now using [serp it](pflow/README.md)

## 2024-01-19
- 🆙 [Balancer.py](aoai/balancer.py) and [chat.py](aoai/chat.py) updated to support the new Python SDK v1.0.0 and higher
    > NOTE: Got rid of the deployment list so back to REST API for that
- 🆙 [azsqlnlp.py](aoai/azsqlnlp.py) updated to support the new Python SDK v1.0.0 and higher
- 🆙 [chatbot.py](aoai/chatbot.py) updated to support the new Python SDK v1.0.0 and higher
- 🆙 [bingit.py](aoai/bingit.py) updated to support the new Python SDK v1.0.0 and higher
- 🆙 [aoai.py](aoai/aoai.py) updated to support the new Python SDK v1.0.0 and higher
- 🆙 [aoaihelper.ipynb](aoai/aoaihelper.ipynb) removed `import openai` as it wasn't used (bad code)

# My install
- Have a PC and a Mac (MacBook Pro mid-2012...please send me a new one)
- VS Code
    - Extensions: REST Client (must have)
- PowerShell Core (Not Windows PowerShell)
- Windows: Running on WSL (Windows Subsystem for Linux)

# [Azure OpenAI](aoai/README.md)
This is all the buzz as of late and I am quite impressed with what we are able to do with it. I have included an initial script in my [aoai](aoai) folder to review. This includes a couple of examples:
- Use NLP to query a Azure SQL database
- Use PowerShell to test a ton of models and examples
- Python notebook with examples and SQL generative

# [Power BI](powerbi/README.md)

# [SQL](sql/README.md)

# Azure Data Explorer
Have a complete [walkthrough](data-explorer/free-cluster-demo.md) using a Free Cluster (No cost) to test ADX
