import openai
import os
from dotenv import load_dotenv
import requests

def test_transcribe_api(path):
    url = "https://deforum.dev/api/v1/transcribe"

    with open(path, 'rb') as f:
        files = {'file': f}
        response = requests.post(url, files=files)

    print(response.json())

if __name__ == "__main__":
    f = '/Users/minjunes/ghost/audios/ex.m4a'
    #f = '/Users/minjunes/Downloads/Choosing Writing as a Career.m4a'
    test_transcribe_api(f)

    