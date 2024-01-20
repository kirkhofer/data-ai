# TODO: Create a prompt flow like Bing It

# New install

# Run streamlit app

# Create the flow from scratch

```bash
pf flow init --flow serp-it --type chat

```

- Update the flow.dag.yaml
    - Add a `search_history` node to call serp


# Prerequisites
1. Install dependencies
```bash
   pip install -r requirements.txt
```

2. Install and configure [Prompt flow for VS Code extension](https://marketplace.visualstudio.com/items?itemName=prompt-flow.prompt-flow) follow [Quick Start Guide](https://microsoft.github.io/promptflow/how-to-guides/quick-start.html). (_This extension is optional but highly recommended for flow development and debugging._)

3. Deploy an OpenAI or Azure OpenAI chat model (e.g. gpt4 or gpt-35-turbo-16k).  Follow the [how-to](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/create-resource?pivots=web-portal) for an Azure OpenAI example.

## Quick Start ⚡

**Setup a connection for your API key**

For OpenAI key, establish a connection by running the command, using the `openai.yaml` file in the `my_chatbot` folder, which stores your OpenAI key (override keys and name with --set to avoid yaml file changes):

```sh
pf connection create --file ./my_chatbot/openai.yaml --set api_key=<your_api_key> --name open_ai_connection
```

For Azure OpenAI key, establish the connection by running the command, using the `azure_openai.yaml` file:

```sh
pf connection create --file ./my_chatbot/azure_openai.yaml --set api_key=<your_api_key> api_base=<your_api_base> --name open_ai_connection
```

**Chat with your flow**

In the `my_chatbot` folder, there's a `flow.dag.yaml` file that outlines the flow, including inputs/outputs, nodes,  connection, and the LLM model, etc

> Note that in the `chat` node, we're using a connection named `open_ai_connection` (specified in `connection` field) and the `gpt-35-turbo` model (specified in `deployment_name` field). The deployment_name filed is to specify the OpenAI model, or the Azure OpenAI deployment resource.

Interact with your chatbot by running: (press `Ctrl + C` to end the session)

```sh
pf flow test --flow ./my_chatbot --interactive
```