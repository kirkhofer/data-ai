import streamlit as st 
import time
import os
import requests
import json

endpoint = st.secrets.vision.endpoint
key = st.secrets.vision.key


def get_caption(image_file):
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

st.title("Say Cheese! 📸")
st.markdown("Take a photo and I'll describe it for you.")

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
