import streamlit as st
import promptflow as pf
import json



st.text_input("Search",key="txtSearch",value="What is the capital of France?")
if st.button("Search"):
    cli = pf.PFClient()

    result=cli.test(flow="serp-it",inputs={"question":st.session_state.txtSearch})

    if hasattr(result['answer'], "__iter__") and hasattr(result['answer'], "__next__"):
        answer_text = ""
        for token in result['answer']:
            answer_text += token
        answer = answer_text
        st.write(answer)
    with st.expander("See more info"):
        st.write(result['search_history'])