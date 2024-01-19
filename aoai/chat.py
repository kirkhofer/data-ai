# Borrowed some design from here and added some twists for 429 errors
# https://github.com/avrabyt/OpenAI-Streamlit-YouTube/blob/451de7a5b9b2cfcd55ff828e0ddb213f2274cf8e/Stream-Argument/app.py
# Still need this import for the RateLimitError
import openai
from openai import AzureOpenAI
import streamlit as st
# from streamlit_pills import pills
import os  
import json, requests
from tenacity import retry, wait_random_exponential, stop_after_attempt,retry_if_exception_type,stop_after_delay
#do this to load the env variables
from dotenv import load_dotenv
from balancer import AOAIBalancer

load_dotenv()

path="json.env"
if os.path.exists(path):
    # load json.env from file
    with open(path) as json_file:
        data = json.load(json_file)

envs=[]
looper = AOAIBalancer(data)

def Get_CompletionREST(prompt,max_tokens=250,temperature=0.5,model="text-davinci-003",streaming=False):
# url = 'https://jsonplaceholder.typicode.com/posts/1'
# get_stream(url)

    env=looper.getModel(model)

    key=env['key']
    endpoint=env['endpoint']

    headers={"Content-Type":"application/json","api-key":key}
    uri = f"{endpoint}openai/deployments/{model}/completions?api-version=2022-12-01"

    body={
        "prompt": prompt,
        "max_tokens":max_tokens,
        "temperature":temperature,
        "stream":streaming
    }

    report=[]

    s = requests.Session()
    i=0
    with s.post(uri, headers=headers, json=body, stream=streaming) as resp:
        for line in resp.iter_lines():
            if len(line) > 0:
                utf8_line = line.decode('utf-8')
                try:
                    if streaming:
                        detail = utf8_line.split(': ')[-1]  
                    else:
                        detail = utf8_line
                    if detail == '[DONE]':
                        st.write("DONE")
                    else:
                        data = json.loads(detail)
                        if 'choices' in data:
                            report.append(data['choices'][0]['text'])
                            result = "".join(report).strip()
                            result = result.replace("\n", "")        
                            res_box.markdown(f'*{result}*') 
                except Exception as e:
                    st.write("Error",str(e))
                    st.write(line)

@retry(retry=retry_if_exception_type(openai.RateLimitError),wait=wait_random_exponential(min=1, max=20), stop=stop_after_attempt(6) | stop_after_delay(5))
def get_openai_response(prompt,max_tokens=250,temperature=0.5,model="text-davinci-003",streaming=False):

    env=looper.getModel(model)
    client = AzureOpenAI(api_key=env['key'], azure_endpoint=env['endpoint'], api_version="2023-03-15-preview")

    exp.write(f"Trying endpoint {client.base_url}")
    try:
        if streaming:
            report = []
            # Looping over the response
            for resp in client.Completion.create(model=model,
                                                prompt=prompt,
                                                max_tokens=max_tokens, 
                                                temperature = temperature,
                                                n=1,
                                                stream=False):
                report.append(resp.choices[0].text)
                result = "".join(report).strip()
                result = result.replace("\n", "")       
                res_box.markdown(f'*{result}*') 

        else:
            completions = client.Completion.create(model=model,
                                                prompt=user_input,
                                                max_tokens=max_tokens, 
                                                temperature = temperature,
                                                stream = False)
            result = completions.choices[0].text

            res_box.write(result)
    except openai.RateLimitError as e:
        exp.error(f"OpenAI API Rate Limit Error: {e}")
        looper.incrementModel(model)
        raise e

@retry(retry=retry_if_exception_type(openai.RateLimitError),wait=wait_random_exponential(min=1, max=20), stop=stop_after_attempt(6) | stop_after_delay(5))
def get_openai_Chat(messages,max_tokens=250,temperature=0.5,model="gpt-35-turbo",streaming=False):
    env=looper.getModel(model)
    client = AzureOpenAI(api_key=env['key'], azure_endpoint=env['endpoint'], api_version="2023-03-15-preview")

    exp.write(f"Trying endpoint {client.base_url}")
    try:
        if streaming:
            report = []
            # Looping over the response
            for resp in client.chat.completions.create(model=model,
                                                messages=messages,
                                                max_tokens=max_tokens, 
                                                temperature = temperature,
                                                stream=streaming):
                report.append(resp.choices[0].delta or "")
                result = "".join(report).strip()
                result = result.replace("\n", "")       
                res_box.markdown(f'*{result}*') 

        else:
            completions = client.chat.completions.create(model=model,
                                                messages=messages,
                                                max_tokens=max_tokens, 
                                                temperature = temperature,
                                                stream = streaming)
            result = completions.choices[0].message.content

            res_box.write(result)
    except openai.RateLimitError as e:
        exp.error(f"OpenAI API Rate Limit Error: {e}")
        looper.incrementModel(model)
        raise e       

st.subheader("Chat, Stream, Retry")

# You can also use radio buttons instead
options=["NO Streaming", "Streaming"]
# selected = st.radio("Choose the app", range(len(options)), format_func=lambda x: options[x])
selected = st.radio("Choose whether to stream", options)

callEndpoints=["Completion", "Chat"]
endpointOpt = st.radio("Choose the Endpoint",callEndpoints)

calls=["REST", "OPENAI"]
callOpt = st.radio("Choose the API to use",calls)

user_input = st.text_input("You: ",placeholder = "Ask me anything ...", value="Tell me a short joke",key="input")

if st.button("Submit", type="primary"):
    st.markdown("----")

    res_box = st.empty()
    exp = st.expander("See more info")

    messages=[]
    messages.append({"role":"user","content":user_input})

    streamIt= True if selected == "Streaming" else False
    if callOpt == "REST":
        if endpointOpt == "Completion":
            Get_CompletionREST(user_input, max_tokens=120, temperature = 0.5,streaming=streamIt)
        else:
            st.warning("Chat not supported in REST")
    else:
        if endpointOpt == "Completion":
            get_openai_response(user_input, max_tokens=120, temperature = 0.5,model="text-davinci-003",streaming=streamIt)
        else:
            get_openai_Chat(messages, max_tokens=120, temperature = 0.5,model="gpt-35-turbo",streaming=streamIt)

st.markdown("----")
