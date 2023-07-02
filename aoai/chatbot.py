import streamlit as st
from streamlit_chat import message
import requests
import json
import pandas as pd
import openai
import os
from dotenv import load_dotenv

load_dotenv()

def load_setting(setting_name, session_name,default_value=''):  
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

if 'show_settings' not in st.session_state:  
    st.session_state['show_settings'] = False  

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
    # We can close out the settings now
    st.session_state['show_settings'] = False
    st.session_state.messages[0]['content'] = st.session_state.system

    openai.api_type = "azure"
    openai.api_version = '2022-12-01'
    openai.api_base = f"https://{st.session_state.aoairegion}.api.cognitive.microsoft.com/"
    openai.api_key = st.session_state.aoaikey
    response = openai.Deployment.list()
    st.session_state['deployments'] = []
    for i,dep in enumerate(response['data']):
        st.session_state['deployments'].append(dep['id'])
        if i==0:
            st.session_state['deployment'] = dep['id']

def runQuery():
    openai.api_type="azure"
    openai.api_base = f"https://{st.session_state.aoairegion}.api.cognitive.microsoft.com/"
    openai.api_key = st.session_state.aoaikey
    openai.api_version = st.session_state.aoaiversion

    st.session_state.messages.append({"role":"user","content":st.session_state.txtSearch})
    
    # st.write(f"deployment: {st.session_state.txtDeployment}")
    # st.write(f"aoairegion: {st.session_state.aoairegion}")
    # st.write(f"aoaiversion: {st.session_state.aoaiversion}")
    # st.write(f"aoaikey: {st.session_state.aoaikey}")
    # st.write(st.session_state.messages)

    response = openai.ChatCompletion.create(
        engine=st.session_state.txtDeployment, 
        messages=st.session_state.messages, 
        # messages=[{"role":"user","content":"Tell me a joke"}], 
        temperature=0.7)
    print('Done')
    st.session_state.messages.append({"role":"assistant","content":response['choices'][0]['message']['content']})

    with st.expander("See more info"):
        st.write(response)

with st.sidebar:
    st.button("Settings",on_click=toggleSettings)
    if st.session_state['show_settings']:  
        # with st.expander("Settings",expanded=expandit):
        with st.form("AzureOpenAI"):
            st.radio("Region?",("eastus","francecentral"),key="rbRegion",index=0)
            st.text_input("API Key",key="txtKey",type="password",value=st.session_state.aoaikey)
            st.text_input("API Version",key="txtVersion",value=st.session_state.aoaiversion)
            st.text_area("System Message", value=st.session_state.system,height=100,key="txtSystem")
            st.form_submit_button("Submit",on_click=saveOpenAI)
    if len(st.session_state['deployments'])>0:
        st.selectbox("Deployment",st.session_state['deployments'],key="txtDeployment",index=0)
    st.button("Clear",on_click=lambda: st.session_state.clear())

with st.form("botit"):
    st.text_input("Ask me a question", value=st.session_state.search,key="txtSearch")
    # st.text_area("Ask me a question", value=st.session_state.search,height=100,key="txtSearch")
    st.form_submit_button(label='Submit', on_click=runQuery)

# st.text_input("Question", value=st.session_state.search,key="txtSearch",on_change=runQuery)

if st.session_state['messages']:
    for i in range(len(st.session_state['messages'])):
        isUser = st.session_state.messages[i]['role'] == 'user'        
        if "system" not in st.session_state.messages[i]['role']:
            message(st.session_state.messages[i]['content'], is_user=isUser, key=str(i) + '_user')

