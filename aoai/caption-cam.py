import streamlit as st 
import time
import os
import requests
import json
from io import BytesIO
from PIL import Image
from datetime import datetime

def get_caption(image_file):
    endpoint = st.secrets.vision.endpoint
    key = st.secrets.vision.key    
    
    model = "?api-version=2023-02-01-preview&modelVersion=latest"
    options = "&features=caption,tags,denseCaptions"

    url = f"{endpoint}computervision/imageanalysis:analyze{model}{options}"

    headers = {
        'Content-type': 'application/octet-stream',
        'Ocp-Apim-Subscription-Key': key
    }

    with open(image_file, "rb") as f:
        data = f.read()

    r = requests.post(url, data=data, headers=headers)

    results = r.json()
    return results


def dalle2generation(caption):
    """
    Generate an image from a prompt with Dall e 2
    """
    endpoint = st.secrets.aoai.base
    key = st.secrets.aoai.key        
    # Settings
    api_version = "2022-08-03-preview"
    url = "{}dalle/text-to-image?api-version={}".format(endpoint, api_version)
    headers = {"api-key": key, "Content-Type": "application/json"}
    body = {"caption": caption, "resolution": "1024x1024"}

    # Sending the request
    submission = requests.post(url, headers=headers, json=body)
    if "operation-location" in submission.headers:
        operation_location = submission.headers["Operation-Location"]
        retry_after = submission.headers["Retry-after"]
        status = ""

        while status != "Succeeded":
            time.sleep(int(retry_after))
            response = requests.get(operation_location, headers=headers)
            status = response.json()["status"]

        # Parsing the result
        image_url = response.json()["result"]["contentUrl"]
        response = requests.get(image_url)

        # Saving the generated image
        dalle2image = Image.open(BytesIO(response.content))
        outputfile = "dalle.jpg"
        dalle2image.save(outputfile)

        return outputfile
    else:
        print("Status:", submission.status_code)
        return None
    
st.title("Say Cheese! 📸")
st.markdown("Take a photo and I'll describe it for you.")

dalle_yn=st.radio("Include DALL-E", ("No", "Yes"))
camera_photo = st.camera_input("Take a photo")
if camera_photo is not None:
    with open ('cam.jpg','wb') as file:
          file.write(camera_photo.getbuffer())
    detail = get_caption('cam.jpg')

    if "captionResult" in detail:
        st.write(f"Caption: {detail['captionResult']['text']}")
    if "tagsResult" in detail:
        tags = detail["tagsResult"]["values"]
        tags_str = ",".join(item["name"] for item in tags)
        st.write(f"Tags: {tags_str}")

        image_caption = detail["captionResult"]["text"]
        image_desc = image_caption + "," + tags_str

        if dalle_yn == "Yes":
            outputfile = dalle2generation(image_desc)
            if outputfile is not None:
                st.image(outputfile)

    else:
        st.write("no tags found")
    if "denseCaptionsResult" in detail:
        st.write(f"Dense caption: {detail['denseCaptionsResult']['values'][0]}")

        for idx, value in enumerate(detail['denseCaptionsResult']['values'], start=1):
            st.write(idx, value['text'], "=", round(value['confidence'], 3))

    with st.expander("Raw JSON"):
        st.write(detail)

else:
    st.warning("No photo available")
