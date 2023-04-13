# Azure OpenAI Solutions
Will showcase several options here for different approaches

<!-- [![Open in GitHub Codespaces](https://img.shields.io/static/v1?style=for-the-badge&label=GitHub+Codespaces&message=Open&color=brightgreen&logo=github)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=599293758&machine=standardLinux32gb&devcontainer_path=.devcontainer%2Fdevcontainer.json&location=WestUs2) -->

## Azure OpenAI Subscription
Several assumptions on this part here:
1. Azure OpenAI subscription
    - Request here: https://aka.ms/oai/access 
    > NOTE: To get access soon, do NOT include DALL-E
1. Your deployment names are like the following
    - `gpt-35-turbo`
    - `code-davinci-002`
        > Yes I know this is going away and will update to ONLY use gpt going forward
    - `text-davinci-003`
1. Optional: Search Service
    - With Semantic search enabled
1. Optional: Bing Search
1. Optional: SQL Database either local or in Azure
1. `.env` config needed for python and PowerShell
    ```text
    AOAI_NAME={Name of the resource in azure}
    AOAI_KEY={Key of the OpenAI resource}
    AOAI_ENDPOINT=https://{Name of the resource in azure}.openai.azure.com/

    AZURE_SEARCH_SERVICE={Cognitive Search Service name}
    AZURE_SEARCH_INDEX={Name of the index with the content}
    AZURE_SEARCH_KEY={API Key needed for search}

    BING_KEY={Bing search key}
    BING_ENDPOINT=https://api.bing.microsoft.com/

    SQL_DB_NAME=AdventureWorksDW
    SQL_SERVER=127.0.0.1
    SQL_USER=sa
    SQL_PASSWORD={whatever your password is}
    ```
1. `.streamlit\secrets.toml` needed for streamlit

## PowerShell with REST API
This is a big [script](aoai.ps1) of goodness. Run it (F5) and then just run the same sections later in the script after the `return`

Must have:
- Permissions to run scripts
    - `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
- Optional: PowerShell SQL Server module
    ```powershell
    $mod = (Get-Module SqlServer -ListAvailable)
    
    if( $mod -eq $null -or $mod.Version.Major -lt 21 )
    {
        Install-Module SqlServer -AllowClobber
    }
    Import-Module SQLServer
    ```

Samples include:
- Completion (Code and Text via Davinci and ChatML)
- Chat Completion using GPT Turbo
- Hit a SQL database and use the Schema and Tables to have it return a query for you
- Hit the Bing service and create a "smart" search like the chat in Bing
- Uses the search index from this awesome solution for [Azure Search OpenAI Demo](https://github.com/Azure-Samples/azure-search-openai-demo)

## NLP with Azure SQL using OpenAI
This solution is in Python and requires several things to get up and running on WSL/Ubuntu:
- Install the SQL driver for Linux
- Install the requirments: `pip install -r requirements.txt`
- Create a config file here `.streamlit\secrets.toml`
    - Replace anything in here with your own information
        ```text
        [aoai]
        key="{Azure key from the service}"
        base="https://{Azure Resource name}.openai.azure.com/"
        previewversion="2023-03-15-preview"
        version="2022-12-01"

        [sql]
        db="AdventureWorksDW"
        server="127.0.0.1"
        user="sa"
        pwd="{whatever this is}"
        driver="ODBC Driver 18 for SQL Server"
        ```
- Launch the application: `streamlit run azsqlnlp.py`
