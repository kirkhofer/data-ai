import streamlit as st 
import time
import os
import requests
import json
from io import BytesIO
from PIL import Image
from datetime import datetime
import base64

def get_caption(image_file):
    endpoint = st.secrets.gpt4v.endpoint
    key = st.secrets.gpt4v.key    
    model = st.secrets.gpt4v.model    
    
    url = f"{endpoint}openai/deployments/{model}/chat/completions?api-version=2023-12-01-preview"

    headers = {
        'Content-type': 'application/json',
        'api-key': key
    }

    base_64_encoded_image = base64.b64encode(open(image_file, "rb").read()).decode(
        "ascii"
    )   

    data = { 
        "messages": [ 
            { "role": "system", "content": "You are a helpful assistant." }, # Content can be a string, OR 
            { "role": "user", "content": [       # It can be an array containing strings and images. 
                "Describe this picture:", 
                { "image": base_64_encoded_image }      # Images are represented like this. 
            ] } 
        ], 
        "max_tokens": 100 
    }   

    response = requests.post(url, headers=headers, data=json.dumps(data))   
    if response.status_code == 200:
        result = json.loads(response.text)["choices"][0]["message"]["content"]
        return result
    
    if response.status_code == 429:
        print("[ERROR] Too many requests. Please wait a couple of seconds and try again.")
    
    else:
        print("[ERROR] Error code:", response.status_code)

def dalle3Generation(caption):
    """
    Generate an image from a prompt with Dall e 2
    """
    endpoint = st.secrets.gpt4v.endpoint
    key = st.secrets.gpt4v.key        
    # Settings

    url = f"{endpoint}openai/deployments/Dalle3/images/generations?api-version=2023-12-01-preview"
    headers = {"api-key": key, "Content-Type": "application/json"}
    body = {"prompt": caption, "n":1,"model": "dall-e-3"}

    # Sending the request
    response = requests.post(url, headers=headers, json=body)
    # Parsing the result
    image_url = response.json()["data"][0]["url"]
    response = requests.get(image_url)

    # Saving the generated image
    dalle2image = Image.open(BytesIO(response.content))
    outputfile = "dalle.jpg"
    dalle2image.save(outputfile)

    return outputfile
    
st.title("Say Cheese! 📸")
st.markdown("Take a photo and I'll describe it for you.")

dalle_yn=st.radio("Include DALL-E", ("No", "Yes"))
camera_photo = st.camera_input("Take a photo")
if camera_photo is not None:
    with open ('cam.jpg','wb') as file:
          file.write(camera_photo.getbuffer())
    detail = get_caption('cam.jpg')

    st.write(f"Caption: {detail}")

    if dalle_yn == "Yes":
        outputfile = dalle3Generation(detail)
        if outputfile is not None:
            st.image(outputfile)


else:
    st.warning("No photo available")
