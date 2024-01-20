import streamlit as st
import promptflow as pf
from promptflow.connections import AzureOpenAIConnection,SerpConnection
import json
from dotenv import load_dotenv
import os

#Load the .env file from the parent directory
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

load_setting('AOAI_ENDPOINT','aoaiendpoint','https://azureresource.openai.azure.com/')
load_setting('AOAI_KEY','aoaikey','Get from your Azure Resource')
load_setting('SERP_KEY','serpkey','Get from the site')

def saveSettings():
    st.session_state.aoaikey = st.session_state.txtKey 
    st.session_state.aoaiendpoint = st.session_state.txtEndpoint 
    st.session_state.serpkey = st.session_state.txtSerpKey 

with st.sidebar:
    with st.form("Settings"):
        st.text_input("AOAI Endpoint",key="txtEndpoint",value=st.session_state.aoaiendpoint)
        st.text_input("AOAI Key",key="txtKey",type="password",value=st.session_state.aoaikey)
        st.text_input("SERP Key",key="txtSerpKey",type="password",value=st.session_state.serpkey)
        st.form_submit_button("Submit",on_click=saveSettings)

st.text_input("Search",key="txtSearch",value="What is the capital of France?")
if st.button("Search"):
    message_placeholder = st.empty()
    full_response = ""

    cli = pf.PFClient()
    aoai_conn = AzureOpenAIConnection(name="serp-it-aoai",
                                    api_key=st.session_state.aoaikey,
                                    api_base=st.session_state.aoaiendpoint)
    cli.connections.create_or_update(aoai_conn)

    serp_conn = SerpConnection(name="serp-it",
                            api_key=st.session_state.serpkey)
    cli.connections.create_or_update(serp_conn)

    tflow = pf.load_flow("serp-it")
    tflow.context.streaming = True
    result = tflow(question=st.session_state.txtSearch)

    for token in result["answer"]:
        full_response += token
        #Partial response while it streams
        message_placeholder.markdown(full_response)
    message_placeholder.markdown(full_response)

    with st.expander("See more info"):
        st.write(result['search_history'])