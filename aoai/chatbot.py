'''
Using the https://docs.streamlit.io/knowledge-base/tutorials/build-conversational-apps#build-a-bot-that-mirrors-your-input
tutorial as a starting point, this script will create a chatbot that uses the Azure OpenAI service to respond to user input.
'''
import streamlit as st
from openai import AzureOpenAI
import requests
import os
from dotenv import load_dotenv

load_dotenv()

def load_setting(setting_name, session_name,default_value):  
    """  
    Function to load the setting information from session  
    """  
    if session_name not in st.session_state:  
        if os.environ.get(setting_name) is not None:
            st.session_state[session_name] = os.environ.get(setting_name)
        else:
            st.session_state[session_name] = default_value  

load_setting('AOAI_PREVIEWVERSION','aoaiversion','2023-05-15')
load_setting('AOAI_REGION','aoairegion','eastus')
load_setting('AOAI_KEY','aoaikey','eastus')
load_setting('SEARCH','search','Tell me a joke')
load_setting('SYSTEM','system',"Hi, I'm a bot. Ask me a question.")
load_setting('TOKENS','tokens',1000)
load_setting('TEMPERATURE','temperature',0.7)

if 'show_settings' not in st.session_state:  
    st.session_state['show_settings'] = True  

if 'messages' not in st.session_state:
    st.session_state['messages'] = []
    st.session_state['messages'].append({"role":"system","content":st.session_state.system})

if 'deployments' not in st.session_state:
    st.session_state['deployments'] = []

def toggleSettings():
    st.session_state['show_settings'] = not st.session_state['show_settings']

def saveOpenAI():
    st.session_state.aoaikey = st.session_state.txtKey 
    st.session_state.aoairegion = st.session_state.rbRegion 
    st.session_state.aoaiversion = st.session_state.txtVersion 
    st.session_state.temperture = st.session_state.sldTemp
    st.session_state.tokens = st.session_state.txtTokens
    # We can close out the settings now
    st.session_state['show_settings'] = False
    st.session_state.messages[0]['content'] = st.session_state.system

    # Create a list of deployments
    # As of 1.X you cannot easily list deployments so we have to do this with the REST API
    headers={"Content-Type":"application/json","api-key":st.session_state.aoaikey}
    uri = f"https://{st.session_state.aoairegion}.api.cognitive.microsoft.com/openai/deployments?api-version=2022-12-01"    
    request = requests.get(uri, headers=headers)
    response = request.json()
    st.session_state['deployments'] = []
    for i,dep in enumerate(response['data']):
        st.session_state['deployments'].append(dep['id'])
        if i==0:
            st.session_state['deployment'] = dep['id']

with st.sidebar:
    st.button("Settings",on_click=toggleSettings)
    if st.session_state['show_settings']:  
        # with st.expander("Settings",expanded=expandit):
        with st.form("AzureOpenAI"):
            st.radio("Region?",("eastus","francecentral"),key="rbRegion",index=0)
            st.text_input("API Key",key="txtKey",type="password",value=st.session_state.aoaikey)
            st.text_input("API Version",key="txtVersion",value=st.session_state.aoaiversion)
            st.slider("Temperature",min_value=0.0,max_value=1.0,value=st.session_state.temperature,key="sldTemp")
            st.text_input("Tokens",key="txtTokens",value=st.session_state.tokens)
            st.text_area("System Message", value=st.session_state.system,height=100,key="txtSystem")
            st.form_submit_button("Submit",on_click=saveOpenAI)
    if len(st.session_state['deployments'])>0:
        st.selectbox("Deployment",st.session_state['deployments'],key="txtDeployment",index=0)
    st.button("Clear",on_click=lambda: st.session_state.clear())

if st.session_state['messages']:
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])    

if len(st.session_state.deployments) > 0:
    if prompt := st.chat_input(st.session_state.search):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            message_placeholder = st.empty()
            full_response = ""
            client = AzureOpenAI(api_key=st.session_state.aoaikey, azure_endpoint=f"https://{st.session_state.aoairegion}.api.cognitive.microsoft.com/", api_version=st.session_state.aoaiversion)

            for response in client.chat.completions.create(
                model=st.session_state.deployment,
                messages=[
                    {"role": m["role"], "content": m["content"]}
                    for m in st.session_state.messages
                ],
                temperature=float(st.session_state.temperature),
                max_tokens=int(st.session_state.tokens),
                stream=True,
            ):
                full_response += (response.choices[0].delta.content or "")
                message_placeholder.markdown(full_response + "▌")
            message_placeholder.markdown(full_response)
        st.session_state.messages.append({"role": "assistant", "content": full_response})

